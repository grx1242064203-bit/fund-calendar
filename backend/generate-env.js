#!/usr/bin/env node

/**
 * 环境变量生成脚本
 * 用于生成安全的JWT密钥和加密密钥
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// 生成随机密钥
function generateSecret(length = 32) {
    return crypto.randomBytes(length).toString('hex');
}

// 生成环境变量模板
function generateEnvTemplate() {
    const jwtSecret = generateSecret(32);
    const encryptionKey = generateSecret(32);

    return `# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_NAME=private_fund_calendar
DB_USER=root
DB_PASSWORD=你的数据库密码

# JWT密钥配置 - 已生成随机密钥
JWT_SECRET=${jwtSecret}
JWT_EXPIRES_IN=7d

# 服务器配置
PORT=3001
NODE_ENV=production

# 跨域配置
FRONTEND_URL=https://你的前端域名.vercel.app

# 加密配置 - 已生成随机密钥
ENCRYPTION_KEY=${encryptionKey}

# 日志配置
LOG_LEVEL=info

# 生成时间: ${new Date().toISOString()}
# 请根据实际情况修改数据库配置和前端域名
`;
}

// 主函数
function main() {
    console.log('🔐 生成安全的环境变量配置...\n');

    const envContent = generateEnvTemplate();

    // 输出到控制台
    console.log('📋 环境变量配置内容：');
    console.log('=' .repeat(50));
    console.log(envContent);
    console.log('=' .repeat(50));

    // 提示用户保存
    console.log('\n💡 请将以上内容保存为 .env 文件：');
    console.log('1. 复制上面的内容');
    console.log('2. 在项目根目录创建 .env 文件');
    console.log('3. 将内容粘贴到 .env 文件中');
    console.log('4. 根据实际情况修改数据库密码和前端域名');

    // 询问是否要保存到文件
    console.log('\n❓ 是否要将配置保存到 .env 文件？(y/n)');
    console.log('注意：这会覆盖现有的 .env 文件');

    // 这里为了安全，不自动写入文件，用户需要手动复制
    console.log('\n✅ 配置生成完成！请手动创建 .env 文件并填入以上配置。');
}

// 执行主函数
if (require.main === module) {
    main();
}

module.exports = { generateEnvTemplate, generateSecret };
