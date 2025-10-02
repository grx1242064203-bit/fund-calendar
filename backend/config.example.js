// 配置文件示例
// 复制此文件为 config.js 并填入实际配置

module.exports = {
  // 数据库配置
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    database: process.env.DB_NAME || 'private_fund_calendar',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'your_password_here'
  },

  // JWT密钥配置
  jwt: {
    secret: process.env.JWT_SECRET || 'your_jwt_secret_key_here',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  },

  // 服务器配置
  server: {
    port: process.env.PORT || 3001,
    env: process.env.NODE_ENV || 'production'
  },

  // 跨域配置
  cors: {
    origin: process.env.FRONTEND_URL || 'https://your-frontend-domain.vercel.app',
    credentials: true
  },

  // 加密配置
  encryption: {
    key: process.env.ENCRYPTION_KEY || 'your_32_character_encryption_key_here'
  },

  // 日志配置
  logging: {
    level: process.env.LOG_LEVEL || 'info'
  }
};
