import { randomBytes } from 'node:crypto';

console.log(`SENDA_WEBHOOK_SECRET=${randomBytes(32).toString('base64url')}`);
console.log('\nGuarda este valor tanto en Supabase Vault como en Edge Function Secrets.');
