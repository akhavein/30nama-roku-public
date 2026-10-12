'use strict';
// Preserve the Promise-returning CommonJS API consumed by brs.
module.exports = (...args) => import('@xhmikosr/decompress').then(module => module.default(...args));
