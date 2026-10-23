const dataDir = process.env.DATA_DIR || './data';

module.exports = {
  apps: [
    {
      name: process.env.APP_NAME || 'swarm-mcp',
      script: './src/server.js',
      // SQLite single-writer — never cluster, never pm2 reload (use restart).
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '200M',
      kill_timeout: 5000,
      wait_ready: true,
      // Crash-loop containment: a genuinely broken start (bad config, unreadable
      // DB, etc.) must terminate instead of thrashing — the cluster-mode incident
      // restarted 17x before this existed. pm2 counts a restart toward
      // max_restarts only when the process exits before min_uptime; backoff delay
      // grows exponentially (capped by pm2 at 15s) between each attempt.
      max_restarts: 5,
      min_uptime: 5000,
      exp_backoff_restart_delay: 500,
      error_file: `${dataDir}/logs/pm2-error.log`,
      out_file: `${dataDir}/logs/pm2-out.log`,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    },
  ],
};
