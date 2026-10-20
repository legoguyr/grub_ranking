import { type SupabaseContext } from "@supabase/server";
import { exportJWK, exportPKCS8, generateKeyPair, SignJWT } from "jose";
import { deleteAuthenticatedAccount } from "./index.ts";

// Ephemeral synthetic keys exist only in this local test process. No real Apple,
// Supabase or account credentials are loaded, and network permission is absent.
const secretName = "STAYGRUBBY_APPLE_CREDENTIALS";
const keys = await generateKeyPair("ES256", { extractable: true });
const publicKey = await exportJWK(keys.publicKey);
const privateKey = await exportPKCS8(keys.privateKey);
const appleToken = await new SignJWT({})
  .setProtectedHeader({ alg: "ES256", kid: "synthetic-key" })
  .setSubject("synthetic-apple-subject").setIssuer("https://appleid.apple.com")
  .setAudience("com.guyrettig.StayGrubby").setIssuedAt().setExpirationTime("1h")
  .sign(keys.privateKey);

function check(value: boolean, message: string): asserts value {
  if (!value) throw new Error(message);
}

async function exercise(state: string | undefined, validCode: boolean) {
  check(!Deno.env.has(secretName), "Refusing to run with inherited Apple credentials");
  Deno.env.set(secretName, JSON.stringify({ teamID: "synthetic-team", keyID: "synthetic-key",
    clientID: "com.guyrettig.StayGrubby", privateKey }));
  const events: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.endsWith("/auth/token")) {
      events.push("apple_exchange");
      return Response.json(validCode ? { id_token: appleToken, refresh_token: "synthetic-token" } : {},
        { status: validCode ? 200 : 400 });
    }
    if (url.endsWith("/auth/keys")) return Response.json({ keys: [{ ...publicKey, kid: "synthetic-key", alg: "ES256" }] });
    if (url.endsWith("/auth/revoke")) { events.push("apple_revoke"); return new Response(null, { status: 200 }); }
    throw new Error("Unexpected network destination in isolated test");
  };
  const accountID = "11111111-1111-4111-8111-111111111111";
  let objectsRemain = true;
  const context = {
    userClaims: { id: "synthetic-auth-user" },
    supabase: { schema: () => ({ rpc: async (name: string) => {
      if (name === "account_deletion_state") return { data: { pending: state !== undefined, account_id: accountID, state } };
      events.push(name);
      return { data: { accountID, state: "requested" } };
    } }) },
    supabaseAdmin: {
      auth: { admin: {
        getUserById: async () => ({ data: { user: { identities: [{ provider: "apple",
          identity_id: "22222222-2222-4222-8222-222222222222", identity_data: { sub: "synthetic-apple-subject" } }] } } }),
        deleteUser: async () => { events.push("auth_delete"); return {}; },
      } },
      storage: { from: () => ({
        list: async () => ({ data: objectsRemain ? [{ id: "synthetic-object", name: "display.jpg" }] : [] }),
        remove: async () => { events.push("storage_remove"); objectsRemain = false; return {}; },
      }) },
      schema: () => ({ rpc: async (name: string, args: { target_state?: string }) => {
        events.push(name);
        return { data: { accountID, state: args.target_state ?? "account_erased" } };
      } }),
    },
  } as unknown as SupabaseContext;
  try {
    const response = await deleteAuthenticatedAccount(new Request("https://synthetic.invalid/delete-account", {
      method: "POST", body: JSON.stringify({ authorizationCode: "synthetic-authorization-code" }),
    }), context);
    return { status: response.status, events };
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete(secretName);
  }
}

Deno.test("Retry after Apple revocation rejects an invalid fresh code before any cleanup", async () => {
  const result = await exercise("apple_revoked", false);
  check(result.status === 401, "Fresh Apple verification must fail closed on retry");
  check(JSON.stringify(result.events) === JSON.stringify(["apple_exchange"]), "Cleanup began without fresh Apple verification");
});

Deno.test("Verified retry revokes the new grant before Storage, graph and Auth cleanup", async () => {
  const result = await exercise("apple_revoked", true);
  check(result.status === 200, "Verified retry did not complete");
  check(JSON.stringify(result.events) === JSON.stringify(["apple_exchange", "apple_revoke", "storage_remove",
    "advance_account_deletion", "erase_account_data", "auth_delete"]), "Cleanup/revocation order is incorrect");
});

Deno.test("Auth-cleanup retry still verifies and revokes the fresh Apple grant", async () => {
  const result = await exercise("account_erased", true);
  check(result.status === 200, "Auth cleanup retry did not complete");
  check(JSON.stringify(result.events) === JSON.stringify(["apple_exchange", "apple_revoke", "auth_delete"]), "Auth cleanup bypassed fresh Apple revocation");
});

Deno.test("Initial invalid Apple authorization never creates a deletion job", async () => {
  const result = await exercise(undefined, false);
  check(result.status === 401, "Invalid initial authorization accepted");
  check(JSON.stringify(result.events) === JSON.stringify(["apple_exchange"]), "Deletion job created before Apple verification");
});
