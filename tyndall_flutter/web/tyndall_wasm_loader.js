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
    const imagePointer = module._malloc(bytes.byteLength);
    if (!imagePointer) throw new Error('Not enough memory to process this image.');
    try {
      module.HEAPU8.set(bytes, imagePointer);
      const output = module.ccall(
        'tynsai_predict_image',
        'string',
        ['number', 'number'],
        [imagePointer, bytes.byteLength],
      );
      if (!output || !output.includes('Predicted Mass Percentage:')) {
        throw new Error(output || 'The embedded detector returned no prediction.');
      }
      return output;
    } finally {
      module._free(imagePointer);
    }
  },
};