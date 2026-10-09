export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed.' });

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'OPENAI_API_KEY is not configured on Vercel.' });

  const question = String(req.body?.question ?? '').trim();
  const businessContext = req.body?.businessContext;
  const model = String(req.body?.model || process.env.OPENAI_MODEL || 'gpt-5.6').trim();

  if (!question) return res.status(400).json({ error: 'question is required.' });
  if (!businessContext || typeof businessContext !== 'object') {
    return res.status(400).json({ error: 'businessContext is required.' });
  }

  try {
    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        instructions: "You are BizBrain, a business data analyst. Answer only from the supplied business context. If data is insufficient, say exactly what is missing. Do calculations carefully. Reply in the user's language.",
        input: JSON.stringify({ question, businessContext }),
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      return res.status(response.status).json({ error: data?.error?.message || 'OpenAI request failed.' });
    }

    const answer = Array.isArray(data.output)
      ? data.output.flatMap(item => item.content || []).find(item => item.type === 'output_text')?.text
      : null;

    return res.status(200).json({ answer: answer || '', model });
  } catch (error) {
    return res.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
}
