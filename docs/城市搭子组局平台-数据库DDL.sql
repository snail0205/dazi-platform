-- =====================================================================
-- 城市「搭子」组局平台 —— 数据库设计 DDL（MySQL 8.0）
-- 配套文档：《城市搭子组局平台-需求文档.md》 v0.9
-- 约定：
--   1) 统一 utf8mb4 / InnoDB；物理外键一律不建，用逻辑外键 + 索引。
--   2) 所有金额字段单位为「分」(BIGINT)，避免浮点误差。
--   3) 所有业务表含 created_at/updated_at；逻辑删除用 deleted 或状态位。
--   4) 表名/字段采用 snake_case；中文注释便于对照 PRD。
-- =====================================================================

-- CREATE DATABASE IF NOT EXISTS dazi_platform DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- USE dazi_platform;

-- ---------------------------------------------------------------------
-- 0. 枚举字典（用注释固化，代码中以枚举类/常量实现）
-- ---------------------------------------------------------------------
-- user.status:        0=禁用  1=正常
-- activity.status:    0=草稿  1=待审核  2=报名中  3=已满  4=进行中  5=已结束  6=已取消  7=已驳回
-- activity.fee_mode:  0=免费  1=AA均摊  2=定额入场券  3=押金制
-- member.status:      0=待支付  1=已确认  2=已取消  3=已到场  4=爽约(NO_SHOW)
-- waitlist.status:    0=等待补位  1=已补位  2=已退出
-- pay_order.status:   0=创建  1=支付中  2=支付成功  3=支付失败  4=已关闭  5=已退款
-- refund.status:      0=处理中  1=成功  2=失败
-- evaluation.score:   1~5
-- complaint.status:   0=待处理  1=处理中  2=已驳回  3=已处理

-- ---------------------------------------------------------------------
-- 1. 用户域
-- ---------------------------------------------------------------------
CREATE TABLE `user` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `openid`        VARCHAR(64)     DEFAULT NULL COMMENT '微信小程序openid（微信支付分账需要）',
  `unionid`       VARCHAR(64)     DEFAULT NULL COMMENT '微信unionid（多端打通预留）',
  `phone`         VARCHAR(20)     DEFAULT NULL COMMENT '手机号（脱敏展示）',
  `nick`          VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '昵称',
  `avatar`        VARCHAR(512)    NOT NULL DEFAULT '' COMMENT '头像URL',
  `gender`        TINYINT         NOT NULL DEFAULT 0 COMMENT '0未知 1男 2女',
  `country`       VARCHAR(32)     DEFAULT '' COMMENT '国家',
  `province`      VARCHAR(32)     DEFAULT '' COMMENT '省',
  `city`          VARCHAR(32)     DEFAULT '' COMMENT '市',
  `lng`           DECIMAL(10,6)   DEFAULT NULL COMMENT '常驻经度',
  `lat`           DECIMAL(10,6)   DEFAULT NULL COMMENT '常驻纬度',
  `credit_score`  SMALLINT        NOT NULL DEFAULT 100 COMMENT '信用分(0-120)',
  `credit_level`  TINYINT         NOT NULL DEFAULT 1 COMMENT '信用等级 Lv1~Lv4',
  `host_level`    TINYINT         NOT NULL DEFAULT 0 COMMENT '局主等级 0普通 1-5成长等级',
  `is_verified`   TINYINT         NOT NULL DEFAULT 0 COMMENT '是否实名认证 0否 1是',
  `emergency_contact` JSON        DEFAULT NULL COMMENT '紧急联系人{name,phone}（加密）',
  `status`        TINYINT         NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
  `last_login_at` DATETIME        DEFAULT NULL COMMENT '最后登录时间',
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_openid` (`openid`),
  UNIQUE KEY `uk_phone` (`phone`),
  KEY `idx_city_status` (`city`,`status`),
  KEY `idx_credit` (`credit_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户（搭子/局主同一账号）';

CREATE TABLE `user_tag` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `tag_type`   TINYINT         NOT NULL COMMENT '1=运动项目 2=水平 3=可活动时段',
  `tag_value`  VARCHAR(32)     NOT NULL COMMENT 'tag值，如 categoryId / BEGINNER / WEEKEND_PM',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_tag` (`user_id`,`tag_type`,`tag_value`),
  KEY `idx_tag_value` (`tag_type`,`tag_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户兴趣标签';

CREATE TABLE `user_punishment` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `type`        TINYINT         NOT NULL COMMENT '0=冻结报名权 1=全站封禁',
  `reason_code` VARCHAR(32)     DEFAULT '' COMMENT '规则码，如 NO_SHOW_3TIMES',
  `reason`      VARCHAR(255)    DEFAULT '' COMMENT '原因描述',
  `start_at`    DATETIME        NOT NULL COMMENT '生效时间',
  `end_at`      DATETIME        DEFAULT NULL COMMENT '失效时间，NULL=永久',
  `status`      TINYINT         NOT NULL DEFAULT 0 COMMENT '0生效 1已解除',
  `operator_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作人（运营）',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_status_end` (`user_id`,`status`,`end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户处罚/报名冻结';

-- ---------------------------------------------------------------------
-- 2. 内容与类目
-- ---------------------------------------------------------------------
CREATE TABLE `category` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `parent_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '父类目，0为一级',
  `name`       VARCHAR(32)     NOT NULL COMMENT '类目名，如 羽毛球/徒步',
  `icon`       VARCHAR(512)    NOT NULL DEFAULT '' COMMENT '图标URL',
  `seq`        INT             NOT NULL DEFAULT 0 COMMENT '排序',
  `is_risk`    TINYINT         NOT NULL DEFAULT 0 COMMENT '是否高危项目 1=是',
  `status`     TINYINT         NOT NULL DEFAULT 1 COMMENT '0停用 1启用',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_parent_seq` (`parent_id`,`seq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='运动/活动类目';

-- ---------------------------------------------------------------------
-- 3. 组局域（核心）
-- ---------------------------------------------------------------------
CREATE TABLE `activity` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `host_id`         BIGINT UNSIGNED NOT NULL COMMENT '局主 user.id',
  `category_id`     BIGINT UNSIGNED NOT NULL COMMENT '类目',
  `title`           VARCHAR(100)    NOT NULL COMMENT '局标题',
  `intro`           VARCHAR(2000)   NOT NULL DEFAULT '' COMMENT '局简介/局规',
  `cover_url`       VARCHAR(512)    NOT NULL DEFAULT '' COMMENT '封面图',
  `risk_type`       TINYINT         NOT NULL DEFAULT 0 COMMENT '0普通 1涉水 2登山 3夜跑等高危（同PRD 7.14）',
  `start_at`        DATETIME        NOT NULL COMMENT '开始时间',
  `end_at`          DATETIME        NOT NULL COMMENT '结束时间',
  `location_name`   VARCHAR(200)    NOT NULL COMMENT '场地名',
  `address`         VARCHAR(255)    NOT NULL DEFAULT '' COMMENT '详细地址',
  `lng`             DECIMAL(10,6)   NOT NULL COMMENT '经度',
  `lat`             DECIMAL(10,6)   NOT NULL COMMENT '纬度',
  `geo_hash`        CHAR(8)         NOT NULL COMMENT 'geohash8，附近检索用',
  `slots`           INT             NOT NULL DEFAULT 4 COMMENT '名额上限',
  `member_count`    INT             NOT NULL DEFAULT 0 COMMENT '已确认人数(事务内自增，防超卖兜底)',
  `fee_mode`        TINYINT         NOT NULL DEFAULT 0 COMMENT '0免费 1AA 2定额 3押金',
  `fee_amount`      BIGINT          NOT NULL DEFAULT 0 COMMENT '费用(分)；AA为预估人均',
  `deposit_amount`  BIGINT          NOT NULL DEFAULT 0 COMMENT '押金(分)，fee_mode=3 时有效',
  `entry_rules`     JSON            DEFAULT NULL COMMENT '报名门槛{minCredit,gender:0/1/2,requireVerified,skill:[...]}',
  `refund_policy`   JSON            DEFAULT NULL COMMENT '退款规则{h24:100,h4:50,lt4:0} 百分比，局主可改',
  `status`          TINYINT         NOT NULL DEFAULT 0 COMMENT '状态机见文件头',
  `audit_remark`    VARCHAR(255)    DEFAULT '' COMMENT '驳回原因',
  `audited_by`      BIGINT UNSIGNED DEFAULT NULL COMMENT '审核人(staff.id)',
  `audited_at`      DATETIME        DEFAULT NULL COMMENT '审核时间',
  `cancel_reason`   VARCHAR(255)    DEFAULT '' COMMENT '取消原因',
  `cancelled_at`    DATETIME        DEFAULT NULL COMMENT '取消时间',
  `version`         INT             NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
  `created_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_host_status` (`host_id`,`status`),
  KEY `idx_time_status` (`start_at`,`status`),
  KEY `idx_geo_status` (`geo_hash`,`status`),
  KEY `idx_category_time` (`category_id`,`status`,`start_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='组局(活动)';

CREATE TABLE `activity_member` (
  `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `activity_id`        BIGINT UNSIGNED NOT NULL COMMENT '局ID',
  `user_id`            BIGINT UNSIGNED NOT NULL COMMENT '报名用户',
  `order_no`           VARCHAR(40)     DEFAULT NULL COMMENT '当前支付单号（免费局为空）',
  `fee_mode`           TINYINT         NOT NULL COMMENT '报名时刻的费用模式快照',
  `amount_payable`     BIGINT          NOT NULL DEFAULT 0 COMMENT '应付(分)',
  `amount_paid`        BIGINT          NOT NULL DEFAULT 0 COMMENT '已付(分)',
  `refund_amount`      BIGINT          NOT NULL DEFAULT 0 COMMENT '已退(分)',
  `status`             TINYINT         NOT NULL DEFAULT 1 COMMENT '0待支付 1已确认 2已取消 3已到场 4爽约',
  `attended_at`        DATETIME        DEFAULT NULL COMMENT '到场核销时间',
  `cancel_reason_code` VARCHAR(32)     DEFAULT '' COMMENT '取消原因码 TEMP_CANCEL/…',
  `cancel_at`          DATETIME        DEFAULT NULL COMMENT '取消时间',
  `credit_processed`   TINYINT         NOT NULL DEFAULT 0 COMMENT '信用结算是否已处理 0否 1是(幂等)',
  `remark`             VARCHAR(255)    DEFAULT '' COMMENT '局主备注(如 带球拍)',
  `created_at`         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_activity_user` (`activity_id`,`user_id`),
  KEY `idx_user_status` (`user_id`,`status`),
  KEY `idx_activity_status` (`activity_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='报名成员';

CREATE TABLE `activity_waitlist` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `activity_id` BIGINT UNSIGNED NOT NULL,
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `seq`         INT             NOT NULL COMMENT '队列序号(同局自增)',
  `status`      TINYINT         NOT NULL DEFAULT 0 COMMENT '0等待 1已补位 2已退出',
  `promoted_at` DATETIME        DEFAULT NULL COMMENT '补位时间',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_activity_user` (`activity_id`,`user_id`),
  KEY `idx_activity_seq` (`activity_id`,`seq`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='候补队列';

-- ---------------------------------------------------------------------
-- 4. 交易域（支付/退款/结算）
-- ---------------------------------------------------------------------
CREATE TABLE `pay_order` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_no`         VARCHAR(40)     NOT NULL COMMENT '平台单号(幂等键，全局唯一)',
  `member_id`        BIGINT UNSIGNED DEFAULT NULL COMMENT '报名记录id（押金/报名费）',
  `activity_id`      BIGINT UNSIGNED NOT NULL,
  `user_id`          BIGINT UNSIGNED NOT NULL,
  `biz_type`         TINYINT         NOT NULL COMMENT '1=报名费 2=押金',
  `amount`           BIGINT          NOT NULL COMMENT '金额(分)',
  `channel`          VARCHAR(16)     NOT NULL DEFAULT 'wechat' COMMENT '渠道 wechat/alipay',
  `channel_txn_id`   VARCHAR(64)     DEFAULT NULL COMMENT '渠道交易号',
  `status`           TINYINT         NOT NULL DEFAULT 0 COMMENT '0创建 1支付中 2成功 3失败 4已关闭 5已退款',
  `expire_at`        DATETIME        NOT NULL COMMENT '支付超时时间(15min)',
  `paid_at`          DATETIME        DEFAULT NULL,
  `notify_payload`   JSON            DEFAULT NULL COMMENT '渠道回调原文(对账/排查)',
  `created_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user` (`user_id`),
  KEY `idx_activity` (`activity_id`),
  KEY `idx_expire_status` (`status`,`expire_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='支付单';

CREATE TABLE `refund` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `refund_no`         VARCHAR(40)     NOT NULL COMMENT '平台退款单号(幂等)',
  `order_id`          BIGINT UNSIGNED NOT NULL COMMENT 'pay_order.id',
  `user_id`           BIGINT UNSIGNED NOT NULL,
  `amount`            BIGINT          NOT NULL COMMENT '退款金额(分)',
  `reason_code`       VARCHAR(32)     DEFAULT '' COMMENT 'CANCEL_AUTO/NO_SHOW_REFUND/…',
  `reason`            VARCHAR(255)    DEFAULT '',
  `status`            TINYINT         NOT NULL DEFAULT 0 COMMENT '0处理中 1成功 2失败',
  `channel_refund_id` VARCHAR(64)     DEFAULT NULL,
  `finished_at`       DATETIME        DEFAULT NULL,
  `created_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refund_no` (`refund_no`),
  KEY `idx_order` (`order_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='退款单';

CREATE TABLE `settle_record` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `settle_no`     VARCHAR(40)     NOT NULL COMMENT '结算单号',
  `order_id`      BIGINT UNSIGNED NOT NULL COMMENT 'pay_order.id',
  `activity_id`   BIGINT UNSIGNED NOT NULL,
  `host_id`       BIGINT UNSIGNED NOT NULL COMMENT '收款方(局主或商家)',
  `gross_amount`  BIGINT          NOT NULL COMMENT '原始金额(分)',
  `host_amount`   BIGINT          NOT NULL COMMENT '结算给局主(分)',
  `platform_fee`  BIGINT          NOT NULL COMMENT '平台佣金(分)',
  `status`        TINYINT         NOT NULL DEFAULT 0 COMMENT '0待结算 1已结算 2退款冲正',
  `settled_at`    DATETIME        DEFAULT NULL,
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settle_no` (`settle_no`),
  UNIQUE KEY `uk_order` (`order_id`),
  KEY `idx_host_status` (`host_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='结算/分账记录(V1.1服务商分账启用)';

-- ---------------------------------------------------------------------
-- 5. 信用域
-- ---------------------------------------------------------------------
CREATE TABLE `credit_rule` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(32)     NOT NULL COMMENT '规则码 NO_SHOW/TEMP_CANCEL/...',
  `name`       VARCHAR(64)     NOT NULL,
  `delta`      INT             NOT NULL COMMENT '扣分(负数)/加分(正数)',
  `scene`      VARCHAR(64)     DEFAULT '' COMMENT '触发场景描述',
  `config`     JSON            DEFAULT NULL COMMENT '扩展配置，如{freezeDays:7}',
  `enabled`    TINYINT         NOT NULL DEFAULT 1,
  `remark`     VARCHAR(255)    DEFAULT '',
  `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='信用规则(配置化)';

CREATE TABLE `credit_log` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`        BIGINT UNSIGNED NOT NULL,
  `delta`          INT             NOT NULL COMMENT '变动值(±)',
  `balance_after`  SMALLINT        NOT NULL COMMENT '变动后余额',
  `reason_code`    VARCHAR(32)     NOT NULL COMMENT '对应credit_rule.code',
  `ref_type`       VARCHAR(16)     DEFAULT '' COMMENT 'ACTIVITY/EVALUATION/...',
  `ref_id`         BIGINT UNSIGNED DEFAULT NULL,
  `biz_no`         VARCHAR(40)     DEFAULT '' COMMENT '业务单号(对账/申诉定位)',
  `operator_type`  TINYINT         NOT NULL DEFAULT 0 COMMENT '0系统自动 1运营人工',
  `operator_id`    BIGINT UNSIGNED DEFAULT NULL,
  `appeal_status`  TINYINT         NOT NULL DEFAULT 0 COMMENT '0无申诉 1申诉中 2申诉通过 3申诉驳回',
  `created_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_created` (`user_id`,`created_at`),
  KEY `idx_ref` (`ref_type`,`ref_id`),
  KEY `idx_appeal` (`appeal_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='信用流水(全量、不可删改)';

-- ---------------------------------------------------------------------
-- 6. 评价与治理
-- ---------------------------------------------------------------------
CREATE TABLE `evaluation` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `activity_id` BIGINT UNSIGNED NOT NULL,
  `from_uid`    BIGINT UNSIGNED NOT NULL COMMENT '评价人',
  `to_uid`      BIGINT UNSIGNED NOT NULL COMMENT '被评价人',
  `to_role`     TINYINT         NOT NULL DEFAULT 0 COMMENT '0=局友 1=局主',
  `score`       TINYINT         NOT NULL COMMENT '1~5星',
  `tags`        JSON            DEFAULT NULL COMMENT '标签数组，如["靠谱","水平相符"]',
  `content`     VARCHAR(500)    DEFAULT '' COMMENT '一句话评价',
  `status`      TINYINT         NOT NULL DEFAULT 1 COMMENT '0待复核 1展示 2隐藏',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_act_from_to` (`activity_id`,`from_uid`,`to_uid`),
  KEY `idx_to_uid` (`to_uid`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='互评';

CREATE TABLE `complaint` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_no`   VARCHAR(32)     NOT NULL COMMENT '工单号',
  `reporter_id` BIGINT UNSIGNED NOT NULL,
  `target_type` TINYINT         NOT NULL COMMENT '1=局 2=用户 3=聊天消息',
  `target_id`   BIGINT UNSIGNED NOT NULL,
  `reason_code` VARCHAR(32)     DEFAULT '',
  `reason`      VARCHAR(255)    DEFAULT '',
  `evidence`    JSON            DEFAULT NULL COMMENT '证据：消息/截图URL/到场记录',
  `status`      TINYINT         NOT NULL DEFAULT 0 COMMENT '0待处理 1处理中 2已驳回 3已处理',
  `verdict`     VARCHAR(500)    DEFAULT '' COMMENT '处理结论',
  `operator_id` BIGINT UNSIGNED DEFAULT NULL,
  `processed_at` DATETIME       DEFAULT NULL,
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_no` (`report_no`),
  KEY `idx_status` (`status`,`created_at`),
  KEY `idx_target` (`target_type`,`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='举报/申诉工单(信用申诉复用report_no可扩展字段)';

-- ---------------------------------------------------------------------
-- 7. 消息与聊天
-- ---------------------------------------------------------------------
CREATE TABLE `notification` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `channel`    TINYINT         NOT NULL DEFAULT 0 COMMENT '0=站内 1=微信订阅消息 2=App推送',
  `type`       VARCHAR(32)     NOT NULL COMMENT 'JOIN_SUCCESS/WAITLIST_PROMOTED/REMIND/...',
  `title`      VARCHAR(100)    NOT NULL DEFAULT '',
  `content`    VARCHAR(1000)   NOT NULL DEFAULT '',
  `biz_type`   VARCHAR(32)     DEFAULT '',
  `biz_id`     BIGINT UNSIGNED DEFAULT NULL COMMENT '回跳页面目标id',
  `read_flag`  TINYINT         NOT NULL DEFAULT 0 COMMENT '0未读 1已读',
  `send_status` TINYINT        NOT NULL DEFAULT 0 COMMENT '0待发送 1已发送 2失败',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_read` (`user_id`,`read_flag`,`created_at`),
  KEY `idx_send_status` (`send_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='消息通知';

CREATE TABLE `chat_message` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `activity_id` BIGINT UNSIGNED NOT NULL COMMENT '局id(即群id)',
  `from_uid`    BIGINT UNSIGNED NOT NULL COMMENT '0=系统消息',
  `msg_type`    TINYINT         NOT NULL DEFAULT 0 COMMENT '0文本 1图片 2系统消息',
  `content`     VARCHAR(2000)   NOT NULL COMMENT '文本或图片URL',
  `extra`       JSON            DEFAULT NULL COMMENT '扩展(引用消息等)',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_activity_msg` (`activity_id`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='局内聊天消息(仅已确认成员可见)';

CREATE TABLE `chat_read_mark` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `activity_id`      BIGINT UNSIGNED NOT NULL,
  `user_id`          BIGINT UNSIGNED NOT NULL,
  `last_read_msg_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_act_user` (`activity_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='聊天已读位置';

-- ---------------------------------------------------------------------
-- 8. 运营域（RBAC 与审计）
-- ---------------------------------------------------------------------
CREATE TABLE `staff` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(32)     NOT NULL,
  `password`      VARCHAR(100)    NOT NULL COMMENT 'BCrypt',
  `name`          VARCHAR(32)     NOT NULL DEFAULT '',
  `avatar`        VARCHAR(512)    NOT NULL DEFAULT '',
  `status`        TINYINT         NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
  `last_login_at` DATETIME        DEFAULT NULL,
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='运营账号';

CREATE TABLE `role` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(32)     NOT NULL COMMENT 'ADMIN/AUDITOR/SUPPORT',
  `name`       VARCHAR(32)     NOT NULL,
  `remark`     VARCHAR(255)    DEFAULT '',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='运营角色';

CREATE TABLE `staff_role` (
  `staff_id` BIGINT UNSIGNED NOT NULL,
  `role_id`  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`staff_id`,`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='账号-角色';

CREATE TABLE `permission` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(64)     NOT NULL COMMENT '如 activity:audit / user:ban',
  `name`       VARCHAR(64)     NOT NULL,
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='权限点';

CREATE TABLE `role_permission` (
  `role_id`       BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`role_id`,`permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='角色-权限';

CREATE TABLE `audit_log` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `staff_id`     BIGINT UNSIGNED DEFAULT NULL COMMENT '运营操作人；系统任务为NULL',
  `action`       VARCHAR(64)     NOT NULL COMMENT '如 ACTIVITY_AUDIT / CREDIT_ADJUST',
  `target_type`  VARCHAR(32)     DEFAULT '',
  `target_id`    BIGINT UNSIGNED DEFAULT NULL,
  `detail`       JSON            DEFAULT NULL COMMENT '操作前后快照/原因',
  `ip`           VARCHAR(45)     DEFAULT '',
  `created_at`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_staff_created` (`staff_id`,`created_at`),
  KEY `idx_target` (`target_type`,`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='全量操作审计';

-- ---------------------------------------------------------------------
-- 9. 平台配置
-- ---------------------------------------------------------------------
CREATE TABLE `platform_config` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cfg_key`    VARCHAR(64)     NOT NULL COMMENT '如 CREDIT_RULES/CANCEL_WINDOW_HOURS/COMMISSION_RATE',
  `cfg_value`  JSON            NOT NULL COMMENT '配置值',
  `remark`     VARCHAR(255)    DEFAULT '',
  `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cfg_key` (`cfg_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='平台配置(热更新)';

-- ---------------------------------------------------------------------
-- 初始化种子数据（示意）
-- ---------------------------------------------------------------------
INSERT INTO `credit_rule` (`code`,`name`,`delta`,`config`,`remark`) VALUES
('NO_SHOW','爽约',-20,'{"freezeDays":0}','点名未到'),
('TEMP_CANCEL','临期取消(4h内)',-5,'{"freezeDays":0}','开局前4h内取消'),
('CANCEL_3TIMES','连续3次临取',0,'{"freezeDays":7}','触发冻结报名7天(由Job组合判定)'),
('HOST_CANCEL','局主无故取消整局',-30,'{"downgrade":true}','并降局主等级'),
('FALSE_REPORT','诬告/恶意差评',-15,'{}','申诉核实后'),
('GOOD_ATTEND','正常出席',0,'{}','不计分，仅作为等级恢复依据');

INSERT INTO `role` (`code`,`name`,`remark`) VALUES
('ADMIN','管理员','全部权限'),
('AUDITOR','审核员','局审核+内容审核'),
('SUPPORT','客服','举报/申诉处理、信用调整');
