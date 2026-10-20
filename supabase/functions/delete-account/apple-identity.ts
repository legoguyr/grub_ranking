// Only identities returned by Auth's admin getUserById belong at this boundary.
// Supabase identity_id is a database row UUID, not Apple's subject identifier.
export function linkedAppleSubject(identities: readonly {
  provider: string;
  identity_data?: { [key: string]: unknown };
}[] | undefined): string | undefined {
  const subject = identities?.find(identity => identity.provider === "apple")?.identity_data?.sub;
  return typeof subject === "string" && subject.length > 0 ? subject : undefined;
}
