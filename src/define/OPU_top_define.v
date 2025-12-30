// DDR存储相关宏
// 下采样分块
// 下采样分块单个分块数据量为27648B,长度为该数值/128bit=1728
`define SampleActBaseAddr 33'd0
`define SampleBlockByteSize 16'd27648
`define SampleDataLength  16'd1728
`define SampleFigAddrBias 12'd3072

// 权重存储
// 权重总数据量790012B,长度为该数值/128bit=49375.75(后续需要舍去一部分数据)
`define WgtBaseAddr   33'd3553000000
`define WgtDataLength 16'd49376

// 初筛结果
// 单个结果分块数据量为2B,长度为1
`define OpuResultBaseAddr 33'd3554000000
`define OpuResultLength   16'd1