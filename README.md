# 基于starcoin move的去中心化拍卖所

## 简介
去中心化拍卖场景，有拍卖人和买受人，拍卖人创建拍卖并抵押标的物，并等待开拍。有人参与竞拍并达到起拍价且拍卖时间到则拍卖成功，否则拍卖失败。

### 拍卖方
  * 注册一个拍卖：起拍价，加价幅度，一口价，拍卖起始和结束时间
  * 抵押标的物：传入抵押标的物（目前为自己发布的Token，后续换成NFT），保证金，等待拍卖结束
  * 取消拍卖：取回拍卖品，失去保证金（无人竞拍时给了Dapp发布方，有人竞拍时保证金给了最后竞买者）
  * 拍卖成功：得到拍卖金和保证金
  * 拍卖失败：时间结束，没有达到起拍价或者无人竞拍，拿回标的物和保证金

### 竞拍方
  * 出价：拍卖开始后，可使用STC出价，出价成功抵押STC，并将结束时间延迟N分钟。
  * 一口价：买完直接拍卖成功。
  * 拍卖成功：得到标的物
  * 拍卖失败：取回竞拍金
  * 竞标被超过：取回竞拍金

### 界面
1. 拍卖列表（off-chain api)
2. 创建拍卖（on-chain api)
3. 我的拍卖：我参与的，我发起的（off-chain api)
4. 拍卖详情：参与竞标（on-chain api)

---

## API （On-chain）
### 创建拍卖
{{address}}::AuctionScript::create
创建拍卖，任何人都可以创建，拍卖创建者和拍卖者可以不是同一个人
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|start_time|u64|开拍时间，毫秒时间戳|
|end_time|u64|结束时间，毫秒时间戳|
|start_price|u128|起拍价，即竞价不能低于该价格|
|reserve_price|u128|保留价，时间结束时，如果低于该价格则流拍|
|increments_price|u128|加价幅度，每次叫价均以该数值的倍数增加|
|hammer_price|u128|一口价|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

### 抵押拍品
{{address}}::AuctionScript::deposit
抵押拍品，任何人都可以抵押拍品，抵押之后的这个人会成为该场拍卖的出售方
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|creator|address|创建拍卖的用户地址|
|objective_price|u128|拍卖标的物的份额，当前版本使用Token用作演示|
|deposit_price|u128|拍卖保证金，保证拍卖顺利进行，若撤销则扣留，若流拍或成交则退回|
|reserve_price|u128|保留价，时间结束时，如果低于该价格则流拍|
|BidTokenType|Template|竞拍代币类型|

### 参与竞价
{{address}}::AuctionScript::bid
任何人都可以参与竞价，除了抵押拍品的人
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|start_time|u64|开拍时间，毫秒时间戳|
|end_time|u64|结束时间，毫秒时间戳|
|start_price|u128|起拍价，即竞价不能低于该价格|
|reserve_price|u128|保留价，时间结束时，如果低于该价格则流拍|
|increments_price|u128|加价幅度，每次叫价均以该数值的倍数增加|
|hammer_price|u128|一口价|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

### 查询拍卖信息
{{address}}::AuctionScript::auction_info
查询某用户发布的拍卖信息

请求参数
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|creator|address|拍卖创建者|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

返回参数
|参数名|参数类型|说明|
|------ | ------ | ------ |
|start_time|u64|签名用户身份|
|end_time|u64|拍卖创建者|
|reserve_price|u128|保留价|
|increments_price|u128|加价幅度|
|hammer_price|u128|一口价|
|state|u8|当前状态, 0:初始化， 1: 待开拍, 2: 拍卖中，3: 流拍（未到保留价），4：流拍（无人出价），5：成交|
|buyer|address|当前竞拍人|
|buyer_bid_reserve|u128|竞拍人出价|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

### 一口价购买
{{address}}::AuctionScript::hammer_buy
一口价购买，任何人随时随地都可以出一口价购买

请求参数
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|creator|address|拍卖创建者|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

### 完成拍卖
{{address}}::AuctionScript::completed
拍卖时间结束时调用，调用后分配对应的资源，任何人都可调用

请求参数
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|creator|address|拍卖创建者|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

### 清理拍卖
{{address}}::AuctionScript::destroy
拍卖结束后调用，否则无法创建新的拍卖，该函数由拍卖创建者调用

请求参数
|参数名|参数类型|说明|
|------ | ------ | ------ |
|account|signer|签名用户身份|
|ObjectiveTokenT|Template|标的物代币类型|
|BidTokenType|Template|竞拍代币类型|

--- 

## API（Off-chain）
### 全局查询拍卖列表

option
```url
/auction/list
```

请求参数
|参数名|参数类型|说明|

method:
```
GET
```

response: 
```json
{
  "limit": 10,
  "next": -1,
  "data": [
      {
          "id": 1,
          "address": "0xbd7e8be8fae9f60f2f5136433e36a091",
          "objectiveTokenType": "0xbd7e8be8fae9f60f2f5136433e36a091::Auc::Auc",
          "bidTokenType": "0xbd7e8be8fae9f60f2f5136433e36a091::Auc::Auc"
      }
  ]
}
```

### 查询某拍卖的竞拍记录

option
```url
/auction/bid_record
```

请求参数
|参数名|参数类型|说明|
|creator|string|拍卖创建者用户地址|

method:
```
GET
```

response: 
```json
{
  "limit": 10,
  "next": -1,
  "data": [
      {
          "id": 1,
          "address": "0xbd7e8be8fae9f60f2f5136433e36a091",
          "bid_price": 1000000
      }
  ]
}
```