-- 私募产品开放日管理系统数据库设计
-- 作者：[系统名称]
-- 创建时间：2025年
-- 版本：1.0

-- 用户表 - 存储系统用户信息
CREATE TABLE `users` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
    `phone` VARCHAR(11) NOT NULL UNIQUE COMMENT '手机号',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希',
    `password_salt` VARCHAR(32) NOT NULL COMMENT '密码盐值',
    `role` ENUM('admin', 'user') DEFAULT 'user' COMMENT '用户角色：admin管理员，user普通用户',
    `real_name` VARCHAR(50) COMMENT '真实姓名',
    `email` VARCHAR(100) COMMENT '邮箱地址',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    `last_login` DATETIME COMMENT '最后登录时间',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX `idx_phone` (`phone`),
    INDEX `idx_role` (`role`),
    INDEX `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 产品表 - 存储产品基础信息
CREATE TABLE `products` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '产品ID',
    `product_code` VARCHAR(50) NOT NULL UNIQUE COMMENT '产品代码',
    `product_name` VARCHAR(200) NOT NULL COMMENT '产品名称',
    `description` TEXT COMMENT '产品描述',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    `created_by` INT COMMENT '创建人ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX `idx_product_code` (`product_code`),
    INDEX `idx_product_name` (`product_name`),
    INDEX `idx_is_active` (`is_active`),
    INDEX `idx_created_by` (`created_by`),
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品表';

-- 休市日表 - 存储股市休市日信息
CREATE TABLE `holidays` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '休市日ID',
    `holiday_date` DATE NOT NULL COMMENT '休市日期',
    `holiday_name` VARCHAR(100) NOT NULL COMMENT '休市日名称',
    `holiday_type` ENUM('weekend', 'national', 'other') DEFAULT 'other' COMMENT '休市类型',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    `created_by` INT COMMENT '创建人ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE KEY `uk_holiday_date` (`holiday_date`),
    INDEX `idx_holiday_type` (`holiday_type`),
    INDEX `idx_is_active` (`is_active`),
    INDEX `idx_created_by` (`created_by`),
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='休市日表';

-- 产品开放日类型表 - 存储不同类型的开放日设置
CREATE TABLE `product_open_dates` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '开放日ID',
    `product_id` INT NOT NULL COMMENT '产品ID',
    `open_type` ENUM('both', 'subscribe', 'redeem') NOT NULL COMMENT '开放类型：both申赎，subscribe申购，redeem赎回',
    `open_date` DATE NOT NULL COMMENT '开放日期',
    `period_start_days` INT DEFAULT 0 COMMENT '预约开始前N个交易日',
    `period_end_days` INT DEFAULT 0 COMMENT '预约结束前N个交易日',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    `created_by` INT COMMENT '创建人ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE KEY `uk_product_open_date` (`product_id`, `open_type`, `open_date`),
    INDEX `idx_product_id` (`product_id`),
    INDEX `idx_open_type` (`open_type`),
    INDEX `idx_open_date` (`open_date`),
    INDEX `idx_is_active` (`is_active`),
    INDEX `idx_created_by` (`created_by`),
    FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品开放日表';

-- 预约期表 - 存储手动设置的预约期
CREATE TABLE `product_reservation_periods` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '预约期ID',
    `product_id` INT NOT NULL COMMENT '产品ID',
    `open_type` ENUM('both', 'subscribe', 'redeem') NOT NULL COMMENT '开放类型',
    `period_start_date` DATE NOT NULL COMMENT '预约开始日期',
    `period_end_date` DATE NOT NULL COMMENT '预约结束日期',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    `created_by` INT COMMENT '创建人ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX `idx_product_id` (`product_id`),
    INDEX `idx_open_type` (`open_type`),
    INDEX `idx_period_dates` (`period_start_date`, `period_end_date`),
    INDEX `idx_is_active` (`is_active`),
    INDEX `idx_created_by` (`created_by`),
    FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品预约期表';

-- 用户操作日志表 - 记录重要操作（可选，用于审计）
CREATE TABLE `user_operation_logs` (
    `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '日志ID',
    `user_id` INT NOT NULL COMMENT '操作用户ID',
    `operation_type` VARCHAR(50) NOT NULL COMMENT '操作类型',
    `operation_detail` TEXT COMMENT '操作详情',
    `ip_address` VARCHAR(45) COMMENT 'IP地址',
    `user_agent` TEXT COMMENT '用户代理',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_operation_type` (`operation_type`),
    INDEX `idx_created_at` (`created_at`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户操作日志表';

-- 插入默认管理员用户（手机号：13800138000，密码：admin123）
-- 注意：实际部署时需要修改默认密码
INSERT INTO `users` (`phone`, `password_hash`, `password_salt`, `role`, `real_name`) VALUES
('13800138000', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'salt123456789012345678901234567890', 'admin', '系统管理员');

-- 插入2025年休市日数据
INSERT INTO `holidays` (`holiday_date`, `holiday_name`, `holiday_type`) VALUES
-- 1月休市日
('2025-01-01', '元旦', 'national'),
('2025-01-04', '周六', 'weekend'),
('2025-01-05', '周日', 'weekend'),
('2025-01-11', '周六', 'weekend'),
('2025-01-12', '周日', 'weekend'),
('2025-01-18', '周六', 'weekend'),
('2025-01-19', '周日', 'weekend'),
('2025-01-25', '周六', 'weekend'),
('2025-01-26', '周日', 'weekend'),
('2025-01-27', '除夕', 'national'),
('2025-01-28', '春节', 'national'),
('2025-01-29', '春节', 'national'),
('2025-01-30', '春节', 'national'),
('2025-01-31', '春节', 'national'),
-- 2月休市日
('2025-02-01', '春节', 'national'),
('2025-02-02', '春节', 'national'),
('2025-02-03', '春节', 'national'),
('2025-02-04', '春节', 'national'),
('2025-02-08', '周六', 'weekend'),
('2025-02-09', '周日', 'weekend'),
('2025-02-15', '周六', 'weekend'),
('2025-02-16', '周日', 'weekend'),
('2025-02-22', '周六', 'weekend'),
('2025-02-23', '周日', 'weekend'),
-- 3月休市日
('2025-03-01', '周六', 'weekend'),
('2025-03-02', '周日', 'weekend'),
('2025-03-08', '周六', 'weekend'),
('2025-03-09', '周日', 'weekend'),
('2025-03-15', '周六', 'weekend'),
('2025-03-16', '周日', 'weekend'),
('2025-03-22', '周六', 'weekend'),
('2025-03-23', '周日', 'weekend'),
('2025-03-29', '周六', 'weekend'),
('2025-03-30', '周日', 'weekend'),
-- 4月休市日
('2025-04-04', '清明节', 'national'),
('2025-04-05', '清明节', 'national'),
('2025-04-06', '清明节', 'national'),
('2025-04-07', '清明节', 'national'),
('2025-04-12', '周六', 'weekend'),
('2025-04-13', '周日', 'weekend'),
('2025-04-19', '周六', 'weekend'),
('2025-04-20', '周日', 'weekend'),
('2025-04-26', '周六', 'weekend'),
('2025-04-27', '周日', 'weekend'),
-- 5月休市日
('2025-05-01', '劳动节', 'national'),
('2025-05-02', '劳动节', 'national'),
('2025-05-03', '劳动节', 'national'),
('2025-05-04', '劳动节', 'national'),
('2025-05-05', '劳动节', 'national'),
('2025-05-10', '周六', 'weekend'),
('2025-05-11', '周日', 'weekend'),
('2025-05-17', '周六', 'weekend'),
('2025-05-18', '周日', 'weekend'),
('2025-05-24', '周六', 'weekend'),
('2025-05-25', '周日', 'weekend'),
('2025-05-31', '端午节', 'national'),
-- 6月休市日
('2025-06-01', '端午节', 'national'),
('2025-06-02', '端午节', 'national'),
('2025-06-07', '周六', 'weekend'),
('2025-06-08', '周日', 'weekend'),
('2025-06-14', '周六', 'weekend'),
('2025-06-15', '周日', 'weekend'),
('2025-06-21', '周六', 'weekend'),
('2025-06-22', '周日', 'weekend'),
('2025-06-28', '周六', 'weekend'),
('2025-06-29', '周日', 'weekend'),
-- 7月休市日
('2025-07-05', '周六', 'weekend'),
('2025-07-06', '周日', 'weekend'),
('2025-07-12', '周六', 'weekend'),
('2025-07-13', '周日', 'weekend'),
('2025-07-19', '周六', 'weekend'),
('2025-07-20', '周日', 'weekend'),
('2025-07-26', '周六', 'weekend'),
('2025-07-27', '周日', 'weekend'),
-- 8月休市日
('2025-08-02', '周六', 'weekend'),
('2025-08-03', '周日', 'weekend'),
('2025-08-09', '周六', 'weekend'),
('2025-08-10', '周日', 'weekend'),
('2025-08-16', '周六', 'weekend'),
('2025-08-17', '周日', 'weekend'),
('2025-08-23', '周六', 'weekend'),
('2025-08-24', '周日', 'weekend'),
('2025-08-30', '周六', 'weekend'),
('2025-08-31', '周日', 'weekend'),
-- 9月休市日
('2025-09-06', '周六', 'weekend'),
('2025-09-07', '周日', 'weekend'),
('2025-09-13', '周六', 'weekend'),
('2025-09-14', '周日', 'weekend'),
('2025-09-20', '周六', 'weekend'),
('2025-09-21', '周日', 'weekend'),
('2025-09-27', '中秋节', 'national'),
('2025-09-28', '周日', 'weekend'),
-- 10月休市日
('2025-10-01', '国庆节', 'national'),
('2025-10-02', '国庆节', 'national'),
('2025-10-03', '国庆节', 'national'),
('2025-10-04', '国庆节', 'national'),
('2025-10-05', '国庆节', 'national'),
('2025-10-06', '国庆节', 'national'),
('2025-10-07', '国庆节', 'national'),
('2025-10-08', '国庆节', 'national'),
('2025-10-11', '周六', 'weekend'),
('2025-10-12', '周日', 'weekend'),
('2025-10-18', '周六', 'weekend'),
('2025-10-19', '周日', 'weekend'),
('2025-10-25', '周六', 'weekend'),
('2025-10-26', '周日', 'weekend'),
-- 11月休市日
('2025-11-01', '周六', 'weekend'),
('2025-11-02', '周日', 'weekend'),
('2025-11-08', '周六', 'weekend'),
('2025-11-09', '周日', 'weekend'),
('2025-11-15', '周六', 'weekend'),
('2025-11-16', '周日', 'weekend'),
('2025-11-22', '周六', 'weekend'),
('2025-11-23', '周日', 'weekend'),
('2025-11-29', '周六', 'weekend'),
('2025-11-30', '周日', 'weekend'),
-- 12月休市日
('2025-12-06', '周六', 'weekend'),
('2025-12-07', '周日', 'weekend'),
('2025-12-13', '周六', 'weekend'),
('2025-12-14', '周日', 'weekend'),
('2025-12-20', '周六', 'weekend'),
('2025-12-21', '周日', 'weekend'),
('2025-12-27', '周六', 'weekend'),
('2025-12-28', '周日', 'weekend');

-- 创建视图：获取指定年月的交易日
CREATE VIEW `trading_days_view` AS
SELECT
    DATE_FORMAT(holiday_date, '%Y') as year,
    DATE_FORMAT(holiday_date, '%m') as month,
    DATE_FORMAT(holiday_date, '%d') as day
FROM holidays
WHERE holiday_date >= '2025-01-01'
  AND holiday_date <= '2025-12-31'
  AND is_active = TRUE;

-- 创建视图：产品开放日汇总
CREATE VIEW `product_open_dates_summary` AS
SELECT
    p.product_code,
    p.product_name,
    pod.open_type,
    pod.open_date,
    pod.period_start_days,
    pod.period_end_days,
    CASE pod.open_type
        WHEN 'both' THEN '申购/赎回'
        WHEN 'subscribe' THEN '仅申购'
        WHEN 'redeem' THEN '仅赎回'
    END as open_type_name
FROM products p
JOIN product_open_dates pod ON p.id = pod.product_id
WHERE p.is_active = TRUE AND pod.is_active = TRUE
ORDER BY pod.open_date, p.product_code;

-- 创建索引以提高查询性能
CREATE INDEX `idx_users_phone_active` ON `users` (`phone`, `is_active`);
CREATE INDEX `idx_products_active` ON `products` (`is_active`);
CREATE INDEX `idx_holidays_date_active` ON `holidays` (`holiday_date`, `is_active`);
CREATE INDEX `idx_product_open_dates_product_date` ON `product_open_dates` (`product_id`, `open_date`);
CREATE INDEX `idx_product_reservation_periods_product` ON `product_reservation_periods` (`product_id`, `open_type`);

-- 数据库版本信息表
CREATE TABLE `system_info` (
    `id` INT PRIMARY KEY AUTO_INCREMENT,
    `version` VARCHAR(20) NOT NULL DEFAULT '1.0',
    `installed_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `description` TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `system_info` (`version`, `description`) VALUES ('1.0', '初始数据库结构');
