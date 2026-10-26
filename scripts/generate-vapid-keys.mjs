import { generateKeyPairSync } from 'node:crypto';

const { privateKey, publicKey } = generateKeyPairSync('ec', {
	namedCurve: 'prime256v1'
});

const publicJwk = publicKey.export({ format: 'jwk' });
const privateJwk = privateKey.export({ format: 'jwk' });

if (!publicJwk.x || !publicJwk.y || !privateJwk.d) {
	throw new Error('Node.js no pudo exportar las claves VAPID requeridas.');
}

const uncompressedPublicKey = Buffer.concat([
	Buffer.from([4]),
	Buffer.from(publicJwk.x, 'base64url'),
	Buffer.from(publicJwk.y, 'base64url')
]);

console.log(`PUBLIC_VAPID_PUBLIC_KEY=${uncompressedPublicKey.toString('base64url')}`);
console.log(`SENDA_VAPID_PRIVATE_KEY=${privateJwk.d}`);
console.log('\nGuarda la clave privada solo en variables de entorno del backend.');
