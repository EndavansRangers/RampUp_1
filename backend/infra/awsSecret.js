const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const region = process.env.AWS_REGION || "us-east-1";
const secretId = process.env.DB_SECRET_ID || "tunefy/db";

const sm = new SecretsManagerClient({ region });
let cached;

async function getDbSecret() {
  if (cached) return cached;
  const res = await sm.send(new GetSecretValueCommand({ SecretId: secretId }));
  const str = res.SecretString ?? Buffer.from(res.SecretBinary, "base64").toString("utf8");
  cached = JSON.parse(str);
  return cached;
}

module.exports = { getDbSecret };
