export const hooks = {
  updateConfig(config) {
    config.minimumReleaseAgeExclude ??= ['@hakula139/*'];
    return config;
  },
};
