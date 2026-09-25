package com.dazi.common.exception;

import com.dazi.common.result.ErrorCode;
import lombok.Getter;

@Getter
public class BizException extends RuntimeException {
    private final int code;

    public BizException(ErrorCode errorCode) {
        this(errorCode.getCode(), errorCode.getMsg());
    }

    public BizException(ErrorCode errorCode, String msg) {
        this(errorCode.getCode(), msg);
    }

    public BizException(int code, String msg) {
        super(msg);
        this.code = code;
    }
}
