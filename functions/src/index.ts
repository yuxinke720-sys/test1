import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Volcengine Doubao endpoints
const DOUBAO_CHAT_URL =
  "https://ark.cn-beijing.volces.com/api/v3/chat/completions";
const DOUBAO_IMAGE_URL =
  "https://ark.cn-beijing.volces.com/api/v3/images/generations";

// Model endpoint IDs — read from .env
const DOUBAO_MODEL =
  process.env.DOUBAO_MODEL_ID ?? "ep-20260409191516-m6xw9";
const DOUBAO_VISION_MODEL =
  process.env.DOUBAO_VISION_MODEL_ID ?? "ep-20260409191516-m6xw9";
const DOUBAO_IMAGE_MODEL =
  process.env.DOUBAO_IMAGE_MODEL_ID ?? "ep-20260409190549-2d5wv";

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
      response = await fetch(DOUBAO_CHAT_URL, {
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

// ═══════════════════════════════════════════════════════════════════
// analyzeAppearance — multimodal vision (photos → text description)
// ═══════════════════════════════════════════════════════════════════

interface AnalyzeAppearanceRequest {
  prompt: string;
  images: string[];
}

export const analyzeAppearance = onCall(
  {region: "asia-northeast1"},
  async (request) => {
    const data = request.data as Partial<AnalyzeAppearanceRequest>;
    const {prompt, images} = data;

    if (!prompt || !images || !Array.isArray(images) || images.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: prompt, images (non-empty array)."
      );
    }

    const apiKey = process.env.VOLCENGINE_API_KEY;
    if (!apiKey || apiKey === "your_api_key_here") {
      logger.error("VOLCENGINE_API_KEY is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Server AI key is not configured."
      );
    }

    logger.info("analyzeAppearance called", {
      promptLength: prompt.length,
      imageCount: images.length,
      prompt: prompt,
    });

    // Build multimodal content array
    const contentParts: Record<string, unknown>[] = [
      {type: "text", text: prompt},
    ];
    for (const b64 of images) {
      contentParts.push({
        type: "image_url",
        image_url: {url: `data:image/jpeg;base64,${b64}`},
      });
    }

    let response: Response;
    try {
      response = await fetch(DOUBAO_CHAT_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: DOUBAO_VISION_MODEL,
          messages: [{role: "user", content: contentParts}],
          max_tokens: 200,
        }),
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Vision API network error", {error: message});
      throw new HttpsError("internal", "Failed to reach AI vision service.");
    }

    if (!response.ok) {
      const errBody = await response.text();
      logger.error("Vision API error", {
        status: response.status,
        body: errBody.slice(0, 500),
      });
      throw new HttpsError(
        "internal",
        `Vision API returned HTTP ${response.status}.`
      );
    }

    interface VisionChoice {
      message?: {content?: string};
    }
    interface VisionResponse {
      choices?: VisionChoice[];
    }

    let json: VisionResponse;
    try {
      json = (await response.json()) as VisionResponse;
    } catch {
      logger.error("Failed to parse vision response as JSON");
      throw new HttpsError("internal", "Invalid response from vision API.");
    }

    const result = json.choices?.[0]?.message?.content;
    if (!result) {
      logger.error("Vision response missing content", {json});
      throw new HttpsError("internal", "Vision API returned empty content.");
    }

    logger.info("analyzeAppearance success", {
      resultLength: result.length,
    });

    return {success: true, storyData: result};
  }
);

// ═══════════════════════════════════════════════════════════════════
// generateImage — text-to-image generation
// ═══════════════════════════════════════════════════════════════════

interface GenerateImageRequest {
  prompt: string;
}

export const generateImage = onCall(
  {region: "asia-northeast1", timeoutSeconds: 120},
  async (request) => {
    const data = request.data as Partial<GenerateImageRequest>;
    const {prompt} = data;

    if (!prompt) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required field: prompt."
      );
    }

    // Image model uses its own API key
    const apiKey =
      process.env.DOUBAO_IMAGE_API_KEY ?? process.env.VOLCENGINE_API_KEY;
    if (!apiKey || apiKey === "your_api_key_here") {
      logger.error("Image API key is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Server image API key is not configured."
      );
    }

    logger.info("generateImage called", {
      promptLength: prompt.length,
      prompt: prompt,
    });

    let response: Response;
    try {
      response = await fetch(DOUBAO_IMAGE_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: DOUBAO_IMAGE_MODEL,
          prompt: prompt,
          response_format: "b64_json",
        }),
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Image API network error", {error: message});
      throw new HttpsError("internal", "Failed to reach image generation API.");
    }

    if (!response.ok) {
      const errBody = await response.text();
      logger.error("Image API error", {
        status: response.status,
        body: errBody.slice(0, 500),
      });
      throw new HttpsError(
        "internal",
        `Image API returned HTTP ${response.status}.`
      );
    }

    interface ImageDataItem {
      b64_json?: string;
    }
    interface ImageResponse {
      data?: ImageDataItem[];
    }

    let json: ImageResponse;
    try {
      json = (await response.json()) as ImageResponse;
    } catch {
      logger.error("Failed to parse image response as JSON");
      throw new HttpsError("internal", "Invalid response from image API.");
    }

    const b64 = json.data?.[0]?.b64_json;
    if (!b64) {
      logger.error("Image response missing b64_json", {
        keys: Object.keys(json),
      });
      throw new HttpsError("internal", "Image API returned no image data.");
    }

    logger.info("generateImage success", {
      b64Length: b64.length,
    });

    return {imageData: b64};
  }
);
