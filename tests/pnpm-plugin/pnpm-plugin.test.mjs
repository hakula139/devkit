import assert from 'node:assert/strict';
import test from 'node:test';

import { hooks } from '../../pnpmfile.mjs';

for (const [name, configured, expected] of [
  ['default', undefined, ['@hakula139/*']],
  ['explicit exclusions', ['example-lib'], ['example-lib']],
  ['empty exclusions', [], []],
]) {
  test(`${name} preserves the caller configuration`, () => {
    const config = {
      minimumReleaseAge: 1440,
      minimumReleaseAgeExclude: configured,
      overrides: { 'example-lib': '1.0.0' },
    };

    const actual = hooks.updateConfig(config);

    assert.deepEqual(actual, {
      minimumReleaseAge: 1440,
      minimumReleaseAgeExclude: expected,
      overrides: { 'example-lib': '1.0.0' },
    });
  });
}
