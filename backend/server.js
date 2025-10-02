const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const Joi = require('joi');

// 导入配置
const config = require('./config');

const app = express();

// 中间件配置
app.use(helmet()); // 安全头
app.use(cors(config.cors)); // 跨域配置
app.use(morgan(config.logging.level)); // 日志
app.use(express.json({ limit: '10mb' })); // JSON解析，增加大小限制以支持Excel数据
app.use(express.urlencoded({ extended: true }));

// 速率限制
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 100, // 每个IP限制100次请求
  message: '请求过于频繁，请稍后再试'
});
app.use(limiter);

// 数据库连接池
const db = mysql.createPool({
  host: config.database.host,
  port: config.database.port,
  user: config.database.user,
  password: config.database.password,
  database: config.database.database,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000
});

// 测试数据库连接
db.getConnection()
  .then(connection => {
    console.log('数据库连接成功');
    connection.release();
  })
  .catch(err => {
    console.error('数据库连接失败:', err);
    process.exit(1);
  });

// 加密工具函数
function encrypt(text) {
  const cipher = crypto.createCipher('aes-256-cbc', config.encryption.key);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

function decrypt(encryptedText) {
  const decipher = crypto.createDecipher('aes-256-cbc', config.encryption.key);
  let decrypted = decipher.update(encryptedText, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

// JWT认证中间件
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: '访问令牌缺失' });
  }

  jwt.verify(token, config.jwt.secret, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '访问令牌无效' });
    }
    req.user = user;
    next();
  });
}

// 管理员权限验证中间件
function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: '需要管理员权限' });
  }
  next();
}

// 日志记录中间件
function logOperation(req, operationType, operationDetail = '') {
  const logData = {
    user_id: req.user.id,
    operation_type: operationType,
    operation_detail: operationDetail,
    ip_address: req.ip,
    user_agent: req.get('User-Agent')
  };

  db.execute(
    'INSERT INTO user_operation_logs (user_id, operation_type, operation_detail, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)',
    [logData.user_id, logData.operation_type, logData.operation_detail, logData.ip_address, logData.user_agent]
  ).catch(err => console.error('日志记录失败:', err));
}

// ==================== 用户认证相关路由 ====================

// 用户注册
app.post('/api/auth/register', async (req, res) => {
  try {
    const { phone, password, realName, email } = req.body;

    // 验证输入
    const schema = Joi.object({
      phone: Joi.string().pattern(/^1[3-9]\d{9}$/).required(),
      password: Joi.string().min(6).required(),
      realName: Joi.string().max(50),
      email: Joi.string().email()
    });

    const { error } = schema.validate({ phone, password, realName, email });
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // 检查手机号是否已存在
    const [existingUsers] = await db.execute(
      'SELECT id FROM users WHERE phone = ? AND is_active = TRUE',
      [phone]
    );

    if (existingUsers.length > 0) {
      return res.status(409).json({ error: '手机号已注册' });
    }

    // 生成盐值和哈希密码
    const saltRounds = 12;
    const salt = bcrypt.genSaltSync(saltRounds);
    const passwordHash = bcrypt.hashSync(password, salt);

    // 创建用户
    const [result] = await db.execute(
      'INSERT INTO users (phone, password_hash, password_salt, real_name, email, role) VALUES (?, ?, ?, ?, ?, ?)',
      [phone, passwordHash, salt, realName || null, email || null, 'user']
    );

    logOperation(req, '用户注册', `注册手机号: ${phone}`);

    res.status(201).json({
      message: '注册成功',
      userId: result.insertId
    });

  } catch (error) {
    console.error('注册失败:', error);
    res.status(500).json({ error: '注册失败，请稍后重试' });
  }
});

// 用户登录
app.post('/api/auth/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    // 验证输入
    const schema = Joi.object({
      phone: Joi.string().pattern(/^1[3-9]\d{9}$/).required(),
      password: Joi.string().required()
    });

    const { error } = schema.validate({ phone, password });
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // 查找用户
    const [users] = await db.execute(
      'SELECT id, phone, password_hash, password_salt, role, real_name FROM users WHERE phone = ? AND is_active = TRUE',
      [phone]
    );

    if (users.length === 0) {
      return res.status(401).json({ error: '手机号或密码错误' });
    }

    const user = users[0];

    // 验证密码
    const isValidPassword = bcrypt.compareSync(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: '手机号或密码错误' });
    }

    // 生成JWT令牌
    const token = jwt.sign(
      {
        id: user.id,
        phone: user.phone,
        role: user.role,
        realName: user.real_name
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    // 更新最后登录时间
    await db.execute(
      'UPDATE users SET last_login = NOW() WHERE id = ?',
      [user.id]
    );

    logOperation(req, '用户登录', `登录手机号: ${phone}`);

    res.json({
      message: '登录成功',
      token,
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        realName: user.real_name
      }
    });

  } catch (error) {
    console.error('登录失败:', error);
    res.status(500).json({ error: '登录失败，请稍后重试' });
  }
});

// 获取当前用户信息
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const [users] = await db.execute(
      'SELECT id, phone, role, real_name, email, last_login, created_at FROM users WHERE id = ? AND is_active = TRUE',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: '用户不存在' });
    }

    res.json({ user: users[0] });
  } catch (error) {
    console.error('获取用户信息失败:', error);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

// ==================== 产品管理相关路由 ====================

// 获取产品列表
app.get('/api/products', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || '';
    const offset = (page - 1) * limit;

    let whereClause = 'WHERE p.is_active = TRUE';
    let params = [];

    if (search) {
      whereClause += ' AND (p.product_code LIKE ? OR p.product_name LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    // 获取总数
    const [countResult] = await db.execute(
      `SELECT COUNT(*) as total FROM products p ${whereClause}`,
      params
    );

    // 获取产品列表
    const [products] = await db.execute(
      `SELECT p.*, u.real_name as created_by_name,
              (SELECT COUNT(*) FROM product_open_dates pod WHERE pod.product_id = p.id AND pod.is_active = TRUE) as open_dates_count
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       ${whereClause}
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    res.json({
      products,
      pagination: {
        page,
        limit,
        total: countResult[0].total,
        pages: Math.ceil(countResult[0].total / limit)
      }
    });

  } catch (error) {
    console.error('获取产品列表失败:', error);
    res.status(500).json({ error: '获取产品列表失败' });
  }
});

// 获取单个产品详情
app.get('/api/products/:id', authenticateToken, async (req, res) => {
  try {
    const productId = req.params.id;

    // 获取产品基本信息
    const [products] = await db.execute(
      `SELECT p.*, u.real_name as created_by_name
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.id = ? AND p.is_active = TRUE`,
      [productId]
    );

    if (products.length === 0) {
      return res.status(404).json({ error: '产品不存在' });
    }

    const product = products[0];

    // 获取产品开放日信息
    const [openDates] = await db.execute(
      `SELECT open_type, open_date, period_start_days, period_end_days
       FROM product_open_dates
       WHERE product_id = ? AND is_active = TRUE
       ORDER BY open_date`,
      [productId]
    );

    // 获取产品预约期信息
    const [reservationPeriods] = await db.execute(
      `SELECT open_type, period_start_date, period_end_date
       FROM product_reservation_periods
       WHERE product_id = ? AND is_active = TRUE
       ORDER BY period_start_date`,
      [productId]
    );

    res.json({
      product,
      openDates,
      reservationPeriods
    });

  } catch (error) {
    console.error('获取产品详情失败:', error);
    res.status(500).json({ error: '获取产品详情失败' });
  }
});

// 创建或更新产品
app.post('/api/products', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { productCode, productName, description, openDates, reservationPeriods } = req.body;

    // 验证输入
    const schema = Joi.object({
      productCode: Joi.string().required(),
      productName: Joi.string().required(),
      description: Joi.string().allow(''),
      openDates: Joi.array().items(Joi.object({
        openType: Joi.string().valid('both', 'subscribe', 'redeem').required(),
        openDate: Joi.date().required(),
        periodStartDays: Joi.number().integer().min(0),
        periodEndDays: Joi.number().integer().min(0)
      })),
      reservationPeriods: Joi.array().items(Joi.object({
        openType: Joi.string().valid('both', 'subscribe', 'redeem').required(),
        periodStartDate: Joi.date().required(),
        periodEndDate: Joi.date().required()
      }))
    });

    const { error } = schema.validate({
      productCode,
      productName,
      description,
      openDates,
      reservationPeriods
    });

    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // 检查产品代码是否已存在
    const [existingProducts] = await db.execute(
      'SELECT id FROM products WHERE product_code = ? AND is_active = TRUE',
      [productCode]
    );

    let productId;

    if (existingProducts.length > 0) {
      // 更新现有产品
      productId = existingProducts[0].id;

      await db.execute(
        'UPDATE products SET product_name = ?, description = ?, updated_at = NOW() WHERE id = ?',
        [productName, description || null, productId]
      );

      // 删除旧的开放日和预约期数据
      await db.execute('DELETE FROM product_open_dates WHERE product_id = ?', [productId]);
      await db.execute('DELETE FROM product_reservation_periods WHERE product_id = ?', [productId]);

    } else {
      // 创建新产品
      const [result] = await db.execute(
        'INSERT INTO products (product_code, product_name, description, created_by) VALUES (?, ?, ?, ?)',
        [productCode, productName, description || null, req.user.id]
      );

      productId = result.insertId;
    }

    // 插入开放日数据
    if (openDates && openDates.length > 0) {
      for (const openDate of openDates) {
        await db.execute(
          `INSERT INTO product_open_dates (product_id, open_type, open_date, period_start_days, period_end_days, created_by)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [productId, openDate.openType, openDate.openDate, openDate.periodStartDays || 0, openDate.periodEndDays || 0, req.user.id]
        );
      }
    }

    // 插入预约期数据
    if (reservationPeriods && reservationPeriods.length > 0) {
      for (const period of reservationPeriods) {
        await db.execute(
          `INSERT INTO product_reservation_periods (product_id, open_type, period_start_date, period_end_date, created_by)
           VALUES (?, ?, ?, ?, ?)`,
          [productId, period.openType, period.periodStartDate, period.periodEndDate, req.user.id]
        );
      }
    }

    logOperation(req, '产品操作', `操作产品: ${productName} (${productCode})`);

    res.status(existingProducts.length > 0 ? 200 : 201).json({
      message: existingProducts.length > 0 ? '产品更新成功' : '产品创建成功',
      productId
    });

  } catch (error) {
    console.error('保存产品失败:', error);
    res.status(500).json({ error: '保存产品失败' });
  }
});

// 删除产品
app.delete('/api/products/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const productId = req.params.id;

    // 获取产品信息用于日志
    const [products] = await db.execute(
      'SELECT product_name, product_code FROM products WHERE id = ?',
      [productId]
    );

    if (products.length === 0) {
      return res.status(404).json({ error: '产品不存在' });
    }

    const product = products[0];

    // 软删除产品（设置为非激活状态）
    await db.execute(
      'UPDATE products SET is_active = FALSE, updated_at = NOW() WHERE id = ?',
      [productId]
    );

    logOperation(req, '删除产品', `删除产品: ${product.product_name} (${product.product_code})`);

    res.json({ message: '产品删除成功' });

  } catch (error) {
    console.error('删除产品失败:', error);
    res.status(500).json({ error: '删除产品失败' });
  }
});

// ==================== 休市日管理相关路由 ====================

// 获取休市日列表
app.get('/api/holidays', authenticateToken, async (req, res) => {
  try {
    const year = req.query.year || new Date().getFullYear();

    const [holidays] = await db.execute(
      `SELECT id, holiday_date, holiday_name, holiday_type
       FROM holidays
       WHERE YEAR(holiday_date) = ? AND is_active = TRUE
       ORDER BY holiday_date`,
      [year]
    );

    res.json({ holidays });

  } catch (error) {
    console.error('获取休市日失败:', error);
    res.status(500).json({ error: '获取休市日失败' });
  }
});

// 添加休市日
app.post('/api/holidays', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { holidayDate, holidayName, holidayType } = req.body;

    // 验证输入
    const schema = Joi.object({
      holidayDate: Joi.date().required(),
      holidayName: Joi.string().required(),
      holidayType: Joi.string().valid('weekend', 'national', 'other').required()
    });

    const { error } = schema.validate({ holidayDate, holidayName, holidayType });
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // 检查是否已存在
    const [existing] = await db.execute(
      'SELECT id FROM holidays WHERE holiday_date = ? AND is_active = TRUE',
      [holidayDate]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: '该日期已有休市日记录' });
    }

    // 添加休市日
    const [result] = await db.execute(
      'INSERT INTO holidays (holiday_date, holiday_name, holiday_type, created_by) VALUES (?, ?, ?, ?)',
      [holidayDate, holidayName, holidayType, req.user.id]
    );

    logOperation(req, '添加休市日', `添加休市日: ${holidayName} (${holidayDate})`);

    res.status(201).json({
      message: '休市日添加成功',
      holidayId: result.insertId
    });

  } catch (error) {
    console.error('添加休市日失败:', error);
    res.status(500).json({ error: '添加休市日失败' });
  }
});

// 删除休市日
app.delete('/api/holidays/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const holidayId = req.params.id;

    // 获取休市日信息用于日志
    const [holidays] = await db.execute(
      'SELECT holiday_name, holiday_date FROM holidays WHERE id = ?',
      [holidayId]
    );

    if (holidays.length === 0) {
      return res.status(404).json({ error: '休市日不存在' });
    }

    const holiday = holidays[0];

    // 软删除休市日
    await db.execute(
      'UPDATE holidays SET is_active = FALSE WHERE id = ?',
      [holidayId]
    );

    logOperation(req, '删除休市日', `删除休市日: ${holiday.holiday_name} (${holiday.holiday_date})`);

    res.json({ message: '休市日删除成功' });

  } catch (error) {
    console.error('删除休市日失败:', error);
    res.status(500).json({ error: '删除休市日失败' });
  }
});

// ==================== 日历数据相关路由 ====================

// 获取指定年月的日历数据
app.get('/api/calendar/:year/:month', authenticateToken, async (req, res) => {
  try {
    const year = parseInt(req.params.year);
    const month = parseInt(req.params.month);

    if (year < 2020 || year > 2030 || month < 1 || month > 12) {
      return res.status(400).json({ error: '年月参数无效' });
    }

    // 获取休市日
    const [holidays] = await db.execute(
      `SELECT DATE_FORMAT(holiday_date, '%Y-%m-%d') as date, holiday_name
       FROM holidays
       WHERE DATE_FORMAT(holiday_date, '%Y-%m') = ?
         AND is_active = TRUE`,
      [`${year}-${String(month).padStart(2, '0')}`]
    );

    // 获取产品开放日和预约期数据
    const [openDates] = await db.execute(
      `SELECT p.product_code, p.product_name, pod.open_type, pod.open_date,
              pod.period_start_days, pod.period_end_days, prp.period_start_date, prp.period_end_date
       FROM products p
       JOIN product_open_dates pod ON p.id = pod.product_id
       LEFT JOIN product_reservation_periods prp ON p.id = prp.product_id AND pod.open_type = prp.open_type
       WHERE p.is_active = TRUE
         AND pod.is_active = TRUE
         AND (DATE_FORMAT(pod.open_date, '%Y-%m') = ?
              OR (prp.id IS NOT NULL AND DATE_FORMAT(prp.period_start_date, '%Y-%m') = ?))
       ORDER BY pod.open_date`,
      [`${year}-${String(month).padStart(2, '0')}`, `${year}-${String(month).padStart(2, '0')}`]
    );

    // 构建日历数据结构
    const calendarData = {
      year,
      month,
      holidays: holidays.reduce((acc, holiday) => {
        acc[holiday.date] = holiday.holiday_name;
        return acc;
      }, {}),
      products: {}
    };

    // 组织产品数据
    openDates.forEach(row => {
      const productKey = row.product_code;

      if (!calendarData.products[productKey]) {
        calendarData.products[productKey] = {
          name: row.product_name,
          openDates: {},
          reservationPeriods: {}
        };
      }

      const dateKey = row.open_date;
      if (!calendarData.products[productKey].openDates[dateKey]) {
        calendarData.products[productKey].openDates[dateKey] = {
          type: row.open_type,
          periodStartDays: row.period_start_days,
          periodEndDays: row.period_end_days
        };
      }

      if (row.period_start_date && row.period_end_date) {
        const periodKey = `${row.period_start_date}_${row.period_end_date}`;
        if (!calendarData.products[productKey].reservationPeriods[periodKey]) {
          calendarData.products[productKey].reservationPeriods[periodKey] = {
            startDate: row.period_start_date,
            endDate: row.period_end_date,
            openType: row.open_type
          };
        }
      }
    });

    res.json(calendarData);

  } catch (error) {
    console.error('获取日历数据失败:', error);
    res.status(500).json({ error: '获取日历数据失败' });
  }
});

// ==================== 管理员功能相关路由 ====================

// 获取用户列表（管理员）
app.get('/api/admin/users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const [users] = await db.execute(
      `SELECT id, phone, role, real_name, email, is_active, last_login, created_at
       FROM users
       ORDER BY created_at DESC`
    );

    res.json({ users });

  } catch (error) {
    console.error('获取用户列表失败:', error);
    res.status(500).json({ error: '获取用户列表失败' });
  }
});

// 重置用户密码（管理员）
app.post('/api/admin/users/:id/reset-password', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const userId = req.params.id;
    const { newPassword } = req.body;

    // 验证输入
    const schema = Joi.object({
      newPassword: Joi.string().min(6).required()
    });

    const { error } = schema.validate({ newPassword });
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // 生成新密码哈希
    const saltRounds = 12;
    const salt = bcrypt.genSaltSync(saltRounds);
    const passwordHash = bcrypt.hashSync(newPassword, salt);

    // 更新密码
    await db.execute(
      'UPDATE users SET password_hash = ?, password_salt = ?, updated_at = NOW() WHERE id = ?',
      [passwordHash, salt, userId]
    );

    // 获取用户信息用于日志
    const [users] = await db.execute(
      'SELECT phone FROM users WHERE id = ?',
      [userId]
    );

    logOperation(req, '重置密码', `重置用户密码: ${users[0]?.phone || '未知'}`);

    res.json({ message: '密码重置成功' });

  } catch (error) {
    console.error('重置密码失败:', error);
    res.status(500).json({ error: '重置密码失败' });
  }
});

// ==================== 错误处理 ====================

// 404处理
app.use('*', (req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

// 全局错误处理
app.use((err, req, res, next) => {
  console.error('未处理的错误:', err);

  // 如果是Joi验证错误，返回详细错误信息
  if (err.isJoi) {
    return res.status(400).json({ error: err.details[0].message });
  }

  // 如果是MySQL错误，返回用户友好的错误信息
  if (err.code) {
    switch (err.code) {
      case 'ER_DUP_ENTRY':
        return res.status(409).json({ error: '数据重复' });
      case 'ER_NO_REFERENCED_ROW_2':
        return res.status(400).json({ error: '关联数据不存在' });
      default:
        return res.status(500).json({ error: '数据库操作失败' });
    }
  }

  res.status(500).json({ error: '服务器内部错误' });
});

// ==================== 服务器启动 ====================

const PORT = config.server.port;

app.listen(PORT, () => {
  console.log(`🚀 服务器已启动，监听端口: ${PORT}`);
  console.log(`📝 环境: ${config.server.env}`);
  console.log(`🔗 前端地址: ${config.cors.origin}`);
});

// 优雅关闭
process.on('SIGTERM', () => {
  console.log('收到 SIGTERM 信号，正在关闭服务器...');
  db.end().then(() => {
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('收到 SIGINT 信号，正在关闭服务器...');
  db.end().then(() => {
    process.exit(0);
  });
});

module.exports = app;
