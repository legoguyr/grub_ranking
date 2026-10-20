import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase, type SupabaseContext } from "@supabase/server";
import { SignJWT, createRemoteJWKSet, importPKCS8, jwtVerify } from "jose";
import { linkedAppleSubject } from "./apple-identity.ts";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_CLIENT_ID = "com.guyrettig.StayGrubby";
const PHOTO_BUCKET = "cooking-photos";
const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

type AppleCredentials = { teamID: string; keyID: string; clientID: string; privateKey: string };
type DeletionState = "requested" | "apple_revoked" | "storage_cleared" | "account_erased";
type DeletionJob = { accountID: string; state: DeletionState; objectKeys?: string[] };

function response(status: number, code: string, message: string) {
  return Response.json({ code, message }, { status });
}

function appleCredentials(): AppleCredentials {
  const encoded = Deno.env.get("STAYGRUBBY_APPLE_CREDENTIALS");
  if (!encoded) throw new Error("server_configuration_unavailable");
  const value = JSON.parse(encoded) as Partial<AppleCredentials>;
  if (!value.teamID || !value.keyID || value.clientID !== APPLE_CLIENT_ID || !value.privateKey) {
    throw new Error("server_configuration_unavailable");
  }
  return value as AppleCredentials;
}

async function clientSecret(credentials: AppleCredentials): Promise<string> {
  const key = await importPKCS8(credentials.privateKey.replaceAll("\\n", "\n"), "ES256");
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: credentials.keyID })
    .setIssuer(credentials.teamID).setSubject(credentials.clientID).setAudience(APPLE_ISSUER)
    .setIssuedAt(now).setExpirationTime(now + 300).sign(key);
}

async function revokeAppleAuthorization(code: string, expectedSubject: string, credentials: AppleCredentials) {
  const secret = await clientSecret(credentials);
  const tokenResponse = await fetch(`${APPLE_ISSUER}/auth/token`, {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: credentials.clientID, client_secret: secret,
      code, grant_type: "authorization_code" }),
  });
  if (!tokenResponse.ok) throw new Error("apple_authorization_invalid");
  const tokens = await tokenResponse.json() as { id_token?: string; refresh_token?: string; access_token?: string };
  if (!tokens.id_token) throw new Error("apple_authorization_invalid");
  const verified = await jwtVerify(tokens.id_token, appleKeys,
    { issuer: APPLE_ISSUER, audience: credentials.clientID });
  if (verified.payload.sub !== expectedSubject) throw new Error("identity_mismatch");
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) throw new Error("apple_authorization_invalid");
  const revokeResponse = await fetch(`${APPLE_ISSUER}/auth/revoke`, {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: credentials.clientID, client_secret: secret, token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token" }),
  });
  if (!revokeResponse.ok) throw new Error("apple_revocation_failed");
}

async function storagePaths(admin: any, prefix: string): Promise<string[]> {
  const bucket = admin.storage.from(PHOTO_BUCKET), paths: string[] = [];
  const visit = async (folder: string) => {
    for (let offset = 0;; offset += 100) {
      const { data, error } = await bucket.list(folder,
        { limit: 100, offset, sortBy: { column: "name", order: "asc" } });
      if (error) throw new Error("storage_cleanup_failed");
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${folder}/${entry.name}`;
        if (entry.id === null) await visit(path); else paths.push(path);
      }
      if (entries.length < 100) break;
    }
  };
  await visit(prefix);
  return paths;
}

async function removeStorage(admin: any, accountID: string, known: string[]) {
  const paths = [...new Set([...known, ...await storagePaths(admin, accountID)])];
  for (let start = 0; start < paths.length; start += 1000) {
    const { error } = await admin.storage.from(PHOTO_BUCKET).remove(paths.slice(start, start + 1000));
    if (error) throw new Error("storage_cleanup_failed");
  }
  if ((await storagePaths(admin, accountID)).length !== 0) throw new Error("storage_cleanup_failed");
}

export async function deleteAuthenticatedAccount(req: Request, ctx: SupabaseContext): Promise<Response> {
    if (req.method !== "POST") return response(405, "method_not_allowed", "Use POST.");
    try {
      const body = await req.json() as { authorizationCode?: unknown };
      const authorizationCode = typeof body.authorizationCode === "string" ? body.authorizationCode : "";
      if (authorizationCode.length < 8 || authorizationCode.length > 4096) {
        return response(400, "invalid_authorization", "Apple verification is required.");
      }
      const userID = ctx.userClaims?.id;
      if (!userID) return response(401, "authentication_required", "Sign in again to continue.");
      const { data: userData, error: userError } = await ctx.supabaseAdmin.auth.admin.getUserById(userID);
      if (userError || !userData.user) return response(401, "authentication_required", "Sign in again to continue.");
      const appleSubject = linkedAppleSubject(userData.user.identities);
      if (typeof appleSubject !== "string" || appleSubject.length === 0) {
        return response(403, "apple_identity_required", "The signed-in Apple account could not be verified.");
      }

      const credentials = appleCredentials();
      const { data: stateData, error: stateError } = await ctx.supabase.schema("api").rpc("account_deletion_state");
      if (stateError) throw new Error("deletion_state_unavailable");
      let state = stateData as { pending: boolean; account_id?: string; state?: DeletionState };
      // A retry obtains a new Apple authorization too. A previous durable stage
      // must never stand in for validating/revoking this request's fresh grant.
      await revokeAppleAuthorization(authorizationCode, appleSubject, credentials);
      let current: DeletionJob;
      if (!state.pending) {
        const { data, error } = await ctx.supabase.schema("api").rpc("begin_account_deletion");
        if (error) throw new Error("deletion_start_failed");
        current = data as DeletionJob;
      } else {
        if (!state.account_id || !state.state) throw new Error("deletion_state_unavailable");
        current = { accountID: state.account_id, state: state.state };
      }
      if (current.state === "requested") {
        const { data, error } = await ctx.supabaseAdmin.schema("api").rpc("advance_account_deletion",
          { target_auth_user: userID, target_state: "apple_revoked" });
        if (error) throw new Error("deletion_progress_failed");
        current = data as DeletionJob;
      }
      if (current.state === "apple_revoked") {
        await removeStorage(ctx.supabaseAdmin, current.accountID, current.objectKeys ?? []);
        const { data, error } = await ctx.supabaseAdmin.schema("api").rpc("advance_account_deletion",
          { target_auth_user: userID, target_state: "storage_cleared" });
        if (error) throw new Error("deletion_progress_failed");
        current = data as DeletionJob;
      }
      if (current.state === "storage_cleared") {
        const { data, error } = await ctx.supabaseAdmin.schema("api").rpc("erase_account_data",
          { target_auth_user: userID });
        if (error) throw new Error("account_cleanup_failed");
        current = data as DeletionJob;
      }
      if (current.state !== "account_erased") throw new Error("deletion_incomplete");
      const { error: deleteUserError } = await ctx.supabaseAdmin.auth.admin.deleteUser(userID, false);
      if (deleteUserError) throw new Error("authentication_cleanup_failed");
      return Response.json({ deleted: true });
    } catch (error) {
      const code = error instanceof Error ? error.message : "deletion_failed";
      if (code === "server_configuration_unavailable")
        return response(503, code, "Account deletion is not configured yet. Please try again later.");
      if (code === "identity_mismatch") return response(403, code, "Use the Apple account linked to StayGrubby.");
      if (code === "apple_authorization_invalid")
        return response(401, code, "Apple verification expired. Please try again.");
      return response(503, "deletion_incomplete", "Your account was not reported deleted. Please try again.");
    }
}

export default {
  fetch: withSupabase({ auth: "user" }, deleteAuthenticatedAccount),
};
