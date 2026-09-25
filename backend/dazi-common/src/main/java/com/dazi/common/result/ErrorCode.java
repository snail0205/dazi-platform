package com.dazi.common.result;

import lombok.Getter;

@Getter
public enum ErrorCode {

    SUCCESS(0, "ok"),
    // ===== 通用 4xxxx =====
    PARAM_INVALID(40000, "参数校验失败"),
    UNAUTHORIZED(40100, "未登录或登录已过期"),
    FORBIDDEN(40300, "无权限"),
    NOT_FOUND(40400, "资源不存在"),
    RATE_LIMITED(42900, "操作过于频繁，请稍后再试"),
    SYSTEM_ERROR(50000, "系统繁忙，请稍后再试"),

    // ===== 报名/局 1xxxx =====
    SLOT_FULL(10001, "名额已满"),
    PAY_TIMEOUT(10002, "报名支付超时，名额已释放"),
    ENTRY_RULE_NOT_MET(10003, "不满足报名条件"),
    TIME_CONFLICT(10004, "与已报名的收费局时间冲突"),
    CREDIT_NOT_ENOUGH(10005, "信用分不足或处于报名冻结期"),
    ACTIVITY_STATUS_INVALID(10006, "当前局状态不允许该操作"),
    ALREADY_JOINED(10007, "已报名，请勿重复操作"),
    ALREADY_WAITLISTED(10008, "已在候补队列"),
    JOIN_CANCELLED(10009, "已取消的报名不可操作"),

    // ===== 支付 2xxxx =====
    PAY_ORDER_NOT_FOUND(20001, "支付单不存在或已关闭"),
    PAY_CHANNEL_FAILED(20002, "支付渠道返回失败，请重试"),
    REFUND_EXCEED(20003, "退款金额超过可退金额"),

    // ===== 信用 3xxxx =====
    APPEAL_INVALID(30001, "申诉已存在或不在可申诉时间窗内");

    private final int code;
    private final String msg;

    ErrorCode(int code, String msg) {
        this.code = code;
        this.msg = msg;
    }


}
