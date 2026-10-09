# BizBrain AI Functions

Firebase callable backend for AI Chat. The Flutter client must authenticate with Firebase Auth before calling `aiChat`.

## Secret

Configure the model key with Firebase Secret Manager; never commit it:

`firebase functions:secrets:set OPENAI_API_KEY`

## Deploy

`cd functions && npm install && cd .. && firebase deploy --only functions`
