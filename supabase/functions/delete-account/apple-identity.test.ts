import { linkedAppleSubject } from "./apple-identity.ts";

Deno.test("Apple verification uses provider subject, never Supabase identity row UUID", () => {
  const identities = [{ provider: "apple", identity_id: "11111111-1111-4111-8111-111111111111",
    identity_data: { sub: "synthetic-apple-subject" } }];
  if (linkedAppleSubject(identities) !== "synthetic-apple-subject") throw new Error("Wrong identity field");
});

Deno.test("Missing, empty or non-Apple subjects fail closed", () => {
  for (const identities of [undefined, [], [{ provider: "apple" }],
    [{ provider: "apple", identity_data: { sub: "" } }],
    [{ provider: "apple", identity_data: { sub: 42 } }],
    [{ provider: "email", identity_data: { sub: "synthetic-subject" } }]]) {
    if (linkedAppleSubject(identities) !== undefined) throw new Error("Unverified subject accepted");
  }
});
