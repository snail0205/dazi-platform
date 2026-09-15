package com.dazi.module.user.entity;


import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("user")
public class User implements Serializable {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String openid;
    private String phone;
    private String nick;
    private String avatar;
    private Integer gender;
    private String country;
    private String province;
    private String city;
    private BigDecimal lng;
    private BigDecimal lat;
    private Integer creditScore;
    private Integer creditLevel;
    private Integer hostLevel;
    private Integer isVerified;
    private String emergencyContact;
    private Integer status;
    private LocalDateTime lastLoginAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
