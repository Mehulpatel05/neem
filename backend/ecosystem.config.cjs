module.exports = {
  apps: [
    {
      name: "neem-api",
      script: "dist/src/index.js",
      instances: 2,
      exec_mode: "cluster",
      env: {
        NODE_ENV: "production",
        PORT: 8787,
      },
    },
  ],
};
