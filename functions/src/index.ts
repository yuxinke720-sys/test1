import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Volcengine Doubao chat completions endpoint
const DOUBAO_API_URL =
  "https://ark.cn-beijing.volces.com/api/v3/chat/completions";

// Model endpoint ID — read from .env, fallback to text model
const DOUBAO_MODEL = process.env.DOUBAO_MODEL_ID ?? "ep-20260409191516-m6xw9";

interface GenerateStoryRequest {
  childName: string;
  theme: string;
  style: string;
  pageCount: number;
  childAppearance?: string;
}

export const generateStory = onCall(
  {region: "asia-northeast1"},
  async (request) => {
    // ── 1. Validate inputs ──────────────────────────────────────────
    const data = request.data as Partial<GenerateStoryRequest>;

    const {childName, theme, style, pageCount, childAppearance} = data;

    if (!childName || !theme || !style || !pageCount) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: childName, theme, style, pageCount."
      );
    }

    if (typeof pageCount !== "number" || pageCount < 1 || pageCount > 12) {
      throw new HttpsError(
        "invalid-argument",
        "pageCount must be a number between 1 and 12."
      );
    }

    // ── 2. Read API key from environment ────────────────────────────
    const apiKey = process.env.VOLCENGINE_API_KEY;

    if (!apiKey || apiKey === "your_api_key_here") {
      logger.error("VOLCENGINE_API_KEY is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Server AI key is not configured. Contact the developer."
      );
    }

    // ── 3. Build prompts ────────────────────────────────────────────
    const appearanceNote = childAppearance
      ? `\nChild's appearance: ${childAppearance}`
      : "";

    const systemPrompt =
      "You are a children's storybook author who writes warm, engaging, " +
      "age-appropriate stories for 3–6 year olds. " +
      "You respond ONLY with a valid JSON array — no markdown, no code " +
      "fences, no extra text.";

    const userPrompt =
      `Write a ${pageCount}-page illustrated children's story.\n\n` +
      `Child's name: ${childName}\n` +
      `Theme: ${theme}\n` +
      `Style: ${style}` +
      `${appearanceNote}\n\n` +
      "For each page, provide:\n" +
      "1. The story text (2-3 sentences, simple vocabulary)\n" +
      "2. A detailed image description for an illustrator (1-2 sentences)\n" +
      '3. A single SF Symbol icon name (e.g. "star.fill", "heart.fill")\n\n' +
      "Respond ONLY with a JSON array:\n" +
      '[{"pageNumber":1,"text":"...","imageDescription":"...","emoji":"star.fill"}]\n\n' +
      `Make ${childName} the hero. End with a positive message.`;

    // ── 4. Call Volcengine Doubao API ───────────────────────────────
    logger.info("generateStory called", {childName, theme, style, pageCount});

    let response: Response;
    try {
      response = await fetch(DOUBAO_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: DOUBAO_MODEL,
          messages: [
            {role: "system", content: systemPrompt},
            {role: "user", content: userPrompt},
          ],
          max_tokens: 4000,
        }),
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Doubao API network error", {error: message});
      throw new HttpsError(
        "unavailable",
        "Failed to reach AI service. Please try again later."
      );
    }

    if (!response.ok) {
      const errBody = await response.text();
      logger.error("Doubao API error", {
        status: response.status,
        body: errBody.slice(0, 500),
      });
      throw new HttpsError(
        "internal",
        `AI service returned HTTP ${response.status}. Please try again later.`
      );
    }

    // ── 5. Extract content and return ───────────────────────────────
    interface DoubaoChoice {
      message?: {content?: string};
    }
    interface DoubaoResponse {
      choices?: DoubaoChoice[];
    }

    let json: DoubaoResponse;
    try {
      json = (await response.json()) as DoubaoResponse;
    } catch {
      logger.error("Failed to parse Doubao response as JSON");
      throw new HttpsError("internal", "Invalid response from AI service.");
    }

    const content = json.choices?.[0]?.message?.content;
    if (!content) {
      logger.error("Doubao response missing content", {json});
      throw new HttpsError("internal", "AI returned empty content.");
    }

    logger.info("generateStory success", {
      childName,
      contentLength: content.length,
    });

    return {success: true, storyData: content};
  }
);
