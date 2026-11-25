import { Ytdl } from '@distube/ytdl-core';
import { extractVideoId, headProbe, UpstreamError } from '../lib/http.js';

export async function downloadV1(urlOrId, options = {}) {
  const { type = 'video', quality = null } = options;
  const videoId = extractVideoId(urlOrId);
  if (!videoId) throw new UpstreamError('invalid youtube url or video id');
  const url = `https://www.youtube.com/watch?v=${videoId}`;
  const isVideo = type !== 'audio';

  const client = new Ytdl();
  const info = await client.getInfo(url);

  const details = info.playerResponse?.videoDetails ?? info.videoDetails ?? {};
  const formats = info.formats || [];

  let candidates;
  if (isVideo) {
    candidates = formats.filter((f) => f.hasVideo && f.hasAudio && f.url);
    if (!candidates.length) candidates = formats.filter((f) => f.hasVideo && f.url);
  } else {
    candidates = formats.filter((f) => f.hasAudio && !f.hasVideo && f.url);
    if (!candidates.length) candidates = formats.filter((f) => f.hasAudio && f.url);
  }

  if (!candidates.length) {
    throw new UpstreamError('no downloadable format available (video may be region blocked or requires login)');
  }

  let chosen = candidates[0];
  if (quality) {
    if (isVideo) {
      const wanted = parseInt(String(quality), 10);
      const exact = candidates.filter((f) => (f.height || 0) === wanted);
      if (exact.length) chosen = exact.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0))[0];
      else {
        const lower = candidates.filter((f) => (f.height || 0) < wanted);
        chosen = (lower.length ? lower : candidates).sort((a, b) => (b.height || 0) - (a.height || 0))[0];
      }
    } else {
      const wanted = parseInt(String(quality), 10);
      const exact = candidates.filter((f) => Math.round((f.audioBitrate || 0)) === wanted);
      if (exact.length) chosen = exact[0];
      else chosen = candidates.sort((a, b) => (b.audioBitrate || 0) - (a.audioBitrate || 0))[0];
    }
  } else {
    chosen = isVideo
      ? candidates.sort((a, b) => (b.height || 0) - (a.height || 0) || (b.bitrate || 0) - (a.bitrate || 0))[0]
      : candidates.sort((a, b) => (b.audioBitrate || 0) - (a.audioBitrate || 0))[0];
  }

  let probe = null;
  try {
    probe = await headProbe(chosen.url, { timeout: 12000 });
  } catch {
    probe = null;
  }

  return {
    engine: 'v1',
    engineName: '@distube/ytdl-core',
    videoId,
    title: details.title || info.videoDetails?.title || null,
    author: details.author?.name ?? info.videoDetails?.author?.name ?? null,
    durationSeconds: details.lengthSeconds ? Number(details.lengthSeconds) : null,
    thumbnail: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
    requested: { type: isVideo ? 'video' : 'audio', quality: quality || null },
    format: {
      itag: chosen.itag,
      container: chosen.container || null,
      mimeType: chosen.mimeType || null,
      codecs: chosen.codecs || null,
      quality: chosen.qualityLabel || chosen.audioQuality || null,
      height: chosen.height || null,
      fps: chosen.fps || null,
      audioBitrate: chosen.audioBitrate || null,
      bitrate: chosen.bitrate || null,
      contentLength: chosen.contentLength ? Number(chosen.contentLength) : null,
      hasVideo: !!chosen.hasVideo,
      hasAudio: !!chosen.hasAudio
    },
    download: {
      url: chosen.url,
      expiresInSeconds: info.playerResponse?.streamingData?.expiresInSeconds
        ? Number(info.playerResponse.streamingData.expiresInSeconds)
        : 21540,
      filename: probe?.filename
        || `${(details.title || videoId).replace(/[^\w\s.-]/g, '').trim().slice(0, 80)}.${chosen.container || (isVideo ? 'mp4' : 'm4a')}`,
      contentType: probe?.contentType || chosen.mimeType || null,
      sizeBytes: probe?.length || (chosen.contentLength ? Number(chosen.contentLength) : null),
      sizeMb: probe?.sizeMb || (chosen.contentLength ? Number((Number(chosen.contentLength) / 1048576).toFixed(2)) : null)
    }
  };
}
