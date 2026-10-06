import createTynsaiModule from './wasm/tyndall_detector.js';

const modulePromise = createTynsaiModule({
  locateFile: (path) => new URL(`wasm/${path}`, document.baseURI).href,
});

window.lumenMindTynsAi = {
  async predict(imageBytes) {
    const module = await modulePromise;
    const loadError = module.ccall('tynsai_load_model', 'string', [], []);
    if (loadError) throw new Error(loadError);

    const bytes = imageBytes instanceof Uint8Array
      ? imageBytes
      : new Uint8Array(imageBytes);
    const output = module.ccall(
      'tynsai_predict_image',
      'string',
      ['array', 'number'],
      [bytes, bytes.length],
    );
    if (!output || !output.includes('Predicted Mass Percentage:')) {
      throw new Error(output || 'The embedded detector returned no prediction.');
    }
    return output;
  },
};