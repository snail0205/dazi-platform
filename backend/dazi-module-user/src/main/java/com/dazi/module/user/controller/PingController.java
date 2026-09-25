package com.dazi.module.user.controller;

import com.dazi.common.exception.BizException;
import com.dazi.common.result.ErrorCode;
import com.dazi.common.result.Result;
import com.dazi.module.user.mapper.UserMapper;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping
public class PingController {

    private final UserMapper userMapper;

    public PingController(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    @GetMapping("/ping")
    public Result<Map<String, Object>> ping() {
        return Result.ok(Map.of("module", "dazi-module-user", "status", "ok"));
    }

    @GetMapping("/ping/db")
    public Result<Map<String, Object>> pingDb() {
        Long count = userMapper.selectCount(null);
        return Result.ok(Map.of("module", "dazi-module-user", "db", "ok", "userCount", count));
    }

    // 临时验证失败路径用，验完可删
    @GetMapping("/ping/fail")
    public Result<Void> pingFail() {
        throw new BizException(ErrorCode.NOT_FOUND);
    }
}