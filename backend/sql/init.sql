-- ===========================================================
-- FitQuant 数据库初始化脚本
-- 创建数据库、表结构、测试数据
-- 使用方式: mysql -u root < sql/init.sql
-- ===========================================================

CREATE DATABASE IF NOT EXISTS fitquant_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fitquant_db;

-- ===========================================================
-- 1. 用户表
-- ===========================================================
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `user_id` char(36) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `password_hash` varchar(128) NOT NULL,
  `nickname` varchar(50) DEFAULT NULL,
  `avatar_url` varchar(256) DEFAULT NULL,
  `identity` enum('beginner','enthusiast','coach') DEFAULT NULL,
  `device_id` varchar(64) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  `updated_at` datetime DEFAULT (now()),
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `ix_users_phone` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================
-- 2. 身体数据记录表
-- ===========================================================
DROP TABLE IF EXISTS `body_records`;
CREATE TABLE `body_records` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `height_cm` float NOT NULL,
  `weight_kg` float NOT NULL,
  `age` int NOT NULL,
  `sex` enum('male','female') NOT NULL,
  `chest_cm` float DEFAULT NULL,
  `waist_cm` float DEFAULT NULL,
  `neck_cm` float DEFAULT NULL,
  `hip_cm` float DEFAULT NULL,
  `body_fat_percent` float DEFAULT NULL,
  `activity_level` varchar(20) DEFAULT NULL,
  `recorded_at` datetime NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`id`),
  KEY `ix_body_records_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================
-- 3. 饮食记录表
-- ===========================================================
DROP TABLE IF EXISTS `meal_records`;
CREATE TABLE `meal_records` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `food_name` varchar(100) NOT NULL,
  `meal_type` varchar(20) NOT NULL,
  `protein_g` float DEFAULT NULL,
  `fat_g` float DEFAULT NULL,
  `carbs_g` float DEFAULT NULL,
  `fiber_g` float DEFAULT NULL,
  `kcal` float DEFAULT NULL,
  `recorded_at` datetime NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`id`),
  KEY `ix_meal_records_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================
-- 4. 训练记录表
-- ===========================================================
DROP TABLE IF EXISTS `training_records`;
CREATE TABLE `training_records` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `exercise_name` varchar(100) NOT NULL,
  `training_type` varchar(20) NOT NULL,
  `sets` int DEFAULT NULL,
  `reps` int DEFAULT NULL,
  `weight_kg` float DEFAULT NULL,
  `duration_minutes` int DEFAULT NULL,
  `estimated_kcal` float DEFAULT NULL,
  `recorded_at` datetime NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`id`),
  KEY `ix_training_records_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================
-- 5. 用药记录表
-- ===========================================================
DROP TABLE IF EXISTS `drug_records`;
CREATE TABLE `drug_records` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `drug_name` varchar(100) NOT NULL,
  `category` varchar(20) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `dosage` varchar(50) DEFAULT NULL,
  `unit` varchar(20) DEFAULT NULL,
  `frequency` varchar(50) DEFAULT NULL,
  `recorded_at` datetime NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`id`),
  KEY `ix_drug_records_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================
-- 6. 测试用户数据（密码统一为 666666 的 SHA256）
-- ===========================================================
INSERT INTO `users` (`user_id`, `phone`, `password_hash`, `nickname`, `avatar_url`, `identity`, `device_id`, `created_at`, `updated_at`) VALUES
('0d700b5d-7a71-4323-90d5-82d5a332c7f9', '13800000001', '94edf28c6d6da38fd35d7ad53e485307f89fbeaf120485c8d17a43f323deee71', 'u1', 'https://cdn.fitquant.com/avatars/0d700b5d.png', 'enthusiast', UUID(), NOW(), NOW()),
('304d267c-4d47-40e8-9d3a-c26ed9acd705', '13800000002', '94edf28c6d6da38fd35d7ad53e485307f89fbeaf120485c8d17a43f323deee71', 'u2', 'https://cdn.fitquant.com/avatars/304d267c.png', 'enthusiast', UUID(), NOW(), NOW()),
('0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '13800000003', '94edf28c6d6da38fd35d7ad53e485307f89fbeaf120485c8d17a43f323deee71', 'u3', 'https://cdn.fitquant.com/avatars/0c7fcb6d.png', 'coach', UUID(), NOW(), NOW()),
('13ede84b-b28c-433c-987e-ddda760da569', '13800000004', '94edf28c6d6da38fd35d7ad53e485307f89fbeaf120485c8d17a43f323deee71', 'u4', 'https://cdn.fitquant.com/avatars/13ede84b.png', 'beginner', UUID(), NOW(), NOW()),
('cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '13800000005', '94edf28c6d6da38fd35d7ad53e485307f89fbeaf120485c8d17a43f323deee71', 'u5', 'https://cdn.fitquant.com/avatars/cf3ac464.png', 'enthusiast', UUID(), NOW(), NOW());

-- ===========================================================
-- 7. 身体数据测试数据
-- ===========================================================
INSERT INTO `body_records` (`id`, `user_id`, `height_cm`, `weight_kg`, `age`, `sex`, `chest_cm`, `waist_cm`, `neck_cm`, `hip_cm`, `body_fat_percent`, `activity_level`, `recorded_at`) VALUES
-- u1: 3 条
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', 175, 75, 25, 'male', 95, 80, 39, 92, 22, 'moderate', '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', 175, 76.5, 25, 'male', 95, 81, 39, 92, 22.5, 'moderate', '2026-07-15 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', 175, 77, 25, 'male', 95, 82, 39, 92, 23, 'moderate', '2026-07-08 00:00:00'),
-- u2: 2 条
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', 165, 58, 28, 'female', 85, 68, 34, 90, 25, 'moderate', '2026-07-22 00:00:00'),
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', 165, 59, 28, 'female', 85, 69, 34, 90, 25.8, 'moderate', '2026-07-12 00:00:00'),
-- u3: 2 条
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', 180, 82, 32, 'male', 105, 78, 42, 95, 15, 'veryActive', '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', 180, 83, 32, 'male', 106, 79, 42, 95, 15.5, 'veryActive', '2026-07-08 00:00:00'),
-- u4: 2 条
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', 160, 50, 22, 'female', 78, 62, 32, 85, 23, 'light', '2026-07-22 00:00:00'),
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', 160, 51, 22, 'female', 78, 63, 32, 85, 23.8, 'light', '2026-06-22 00:00:00'),
-- u5: 2 条
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', 178, 80, 40, 'male', 100, 85, 40, 96, 26, 'moderate', '2026-07-22 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', 178, 82, 40, 'male', 100, 87, 40, 96, 27, 'moderate', '2026-06-22 00:00:00');

-- ===========================================================
-- 8. 饮食记录测试数据
-- ===========================================================
INSERT INTO `meal_records` (`id`, `user_id`, `food_name`, `meal_type`, `protein_g`, `fat_g`, `carbs_g`, `fiber_g`, `kcal`, `recorded_at`) VALUES
-- u1 (4 条)
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '全麦面包+牛奶', 'breakfast', 15, 8, 40, 4, 300, '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '鸡胸肉沙拉', 'lunch', 35, 8, 15, 3, 280, '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '牛肉+米饭+西兰花', 'dinner', 40, 12, 50, 5, 480, '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '蛋白粉', 'snack', 25, 1, 3, 0, 120, '2026-07-22 00:00:00'),
-- u2 (3 条)
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '鸡蛋+燕麦', 'breakfast', 18, 10, 35, 5, 320, '2026-07-22 00:00:00'),
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '三文鱼沙拉', 'lunch', 30, 15, 10, 3, 310, '2026-07-22 00:00:00'),
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '鸡腿+糙米', 'dinner', 35, 10, 40, 4, 420, '2026-07-22 00:00:00'),
-- u3 (3 条)
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '鸡蛋+香蕉+燕麦', 'breakfast', 22, 8, 55, 6, 400, '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '鸡胸+糙米+西兰花', 'lunch', 45, 5, 45, 5, 420, '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '牛排+红薯+芦笋', 'dinner', 50, 20, 35, 6, 540, '2026-07-22 00:00:00'),
-- u4 (3 条)
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '水果酸奶', 'breakfast', 8, 3, 30, 2, 180, '2026-07-22 00:00:00'),
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '蔬菜沙拉+鸡胸', 'lunch', 25, 6, 12, 4, 210, '2026-07-22 00:00:00'),
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '清蒸鱼+米饭', 'dinner', 28, 5, 25, 1, 270, '2026-07-22 00:00:00'),
-- u5 (3 条)
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '全麦三明治', 'breakfast', 12, 10, 35, 3, 290, '2026-07-22 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '牛肉面', 'lunch', 30, 15, 55, 2, 500, '2026-07-22 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '清炒蔬菜+鱼肉', 'dinner', 32, 8, 20, 4, 300, '2026-07-22 00:00:00');

-- ===========================================================
-- 9. 训练记录测试数据
-- ===========================================================
INSERT INTO `training_records` (`id`, `user_id`, `exercise_name`, `training_type`, `sets`, `reps`, `weight_kg`, `duration_minutes`, `estimated_kcal`, `recorded_at`) VALUES
-- u1 (4 条)
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '杠铃卧推', 'strength', 4, 10, 40, 30, 180, '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '跑步机', 'cardio', 0, 0, 0, 20, 150, '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '深蹲', 'strength', 3, 12, 50, 25, 160, '2026-07-21 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '哑铃划船', 'strength', 4, 10, 20, 30, 170, '2026-07-20 00:00:00'),
-- u2 (3 条)
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '瑜伽', 'cardio', 0, 0, 0, 45, 120, '2026-07-22 00:00:00'),
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '椭圆机', 'cardio', 0, 0, 0, 30, 200, '2026-07-21 00:00:00'),
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '哑铃推举', 'strength', 3, 12, 5, 20, 100, '2026-07-20 00:00:00'),
-- u3 (4 条)
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '硬拉', 'strength', 5, 5, 100, 35, 250, '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '引体向上', 'strength', 4, 8, 0, 20, 120, '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '杠铃卧推', 'strength', 5, 5, 80, 30, 220, '2026-07-21 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '椭圆机', 'cardio', 0, 0, 0, 20, 140, '2026-07-20 00:00:00'),
-- u4 (2 条)
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '慢跑', 'cardio', 0, 0, 0, 25, 160, '2026-07-22 00:00:00'),
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '平板支撑', 'cardio', 3, 0, 0, 10, 60, '2026-07-21 00:00:00'),
-- u5 (3 条)
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '杠铃深蹲', 'strength', 4, 10, 60, 30, 200, '2026-07-22 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '跑步机', 'cardio', 0, 0, 0, 25, 180, '2026-07-21 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '哑铃弯举', 'strength', 3, 12, 12, 15, 80, '2026-07-20 00:00:00');

-- ===========================================================
-- 10. 用药记录测试数据
-- ===========================================================
INSERT INTO `drug_records` (`id`, `user_id`, `drug_name`, `category`, `status`, `dosage`, `unit`, `frequency`, `recorded_at`) VALUES
-- u1 (2 条)
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '复合维生素', 'typeA', 'viewing', '1', '粒', '每日1次', '2026-07-22 00:00:00'),
(UUID(), '0d700b5d-7a71-4323-90d5-82d5a332c7f9', '蛋白粉', 'other', 'viewing', '30', 'g', '训练后服用', '2026-07-22 00:00:00'),
-- u2 (1 条)
(UUID(), '304d267c-4d47-40e8-9d3a-c26ed9acd705', '维生素D3', 'typeA', 'viewing', '2000', 'IU', '每日1次', '2026-07-22 00:00:00'),
-- u3 (4 条)
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '肌酸', 'other', 'viewing', '5', 'g', '每日1次', '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '鱼油', 'typeA', 'viewing', '2000', 'mg', '每日2次', '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '支链氨基酸', 'other', 'viewing', '10', 'g', '训练中服用', '2026-07-22 00:00:00'),
(UUID(), '0c7fcb6d-467e-439c-8532-2b416bbe8fb1', '左氧氟沙星', 'typeB', 'viewing', '500', 'mg', '每日1次', '2026-07-22 00:00:00'),
-- u4 (1 条)
(UUID(), '13ede84b-b28c-433c-987e-ddda760da569', '维生素C', 'typeA', 'viewing', '500', 'mg', '每日1次', '2026-07-22 00:00:00'),
-- u5 (2 条 + 1 停用)
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '左氧氟沙星', 'typeB', 'viewing', '500', 'mg', '每日1次', '2026-07-22 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '布洛芬', 'typeA', 'stopped', '200', 'mg', '必要时服用', '2026-07-15 00:00:00'),
(UUID(), 'cf3ac464-8a35-4e06-b07e-5466e3d5f78e', '阿托伐他汀', 'typeB', 'viewing', '10', 'mg', '每日1次', '2026-07-22 00:00:00');
