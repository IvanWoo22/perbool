# Workflow

## PCR产物测序结果突变检测流程

### 测序结果文件

`NJU8XXX_R1.fq.gz` 和 `NJU8XXX_R2.fq.gz`;

### 使用**FastQC**查看测序质量

```bash
fastqc NJU8XXX_R1.fq.gz NJU8XXX_R2.fq.gz
```
较新平台的测序系统（例如 `NovaSeq` ）对于质量分数存在调优，故质量过滤意义不大；

一般测序公司会提供初步质控后的Cleandata，可以直接使用；

### 确保质量可靠后，对测序原始数据初步统计

```bash
pigz -dc NJU8XXX_R1.fq.gz NJU8XXX_R2.fq.gz |
    perl fastq2count.pl \
    >NJU8XXX.count
```

### 根据采用的INDEX序列，准备INDEX文件

`index.txt` 文件内容形如：

```
ATCACG	ATCACG	ATCACG	ATCACG	CGATGT
ACAGTG	ACAGTG	ACAGTG	ACAGTG	GCCAAT
GACGAC	GACGAC	GACGAC	GACGAC	GTGGCC
...
```

每行代表一组PCR产物，行数可自定；

每列分别为 `EGFR-19del` `EGFR-T790M` `EGFR-L858R` `KRAS-G12/13` `TP53-R175H`对应每组PCR的INDEX，相互采用制表符分隔；

### 对野生型和突变型序列进行最后的统计

```bash
perl RBC.pl \
    --index index.txt \
    --count NJU8XXX.count \
    >NJU8XXX.txt
```

`NJU8XXX.txt` 内容为每种PCR产物的野生型和突变型统计，示例如下

```
4029        ### 代表第1组EGFR-19del的野生型reads数；
2           ### 代表第1组EGFR-19del的突变型reads数；
1456778     ### 代表第2组EGFR-19del的野生型reads数；
0           ### 代表第2组EGFR-19del的突变型reads数；
2393857     ### 代表第3组EGFR-19del的野生型reads数；
1           ### 代表第3组EGFR-19del的突变型reads数；


7057        ### 代表第1组EGFR-T790M的野生型reads数；
2
566736
751
1871968
1028


1           ### 代表第1组EGFR-L858R的野生型reads数；
0
920922
865
2515331
3621


1           ### 代表第1组KRAS-G12/13的野生型reads数；
0
920922
865
2515331
3621

......
```