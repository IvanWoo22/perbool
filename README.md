# Workflow
## PCR产物测序结果突变检测流程
#### 测序结果文件
`NJU8XXX_R1.fq.gz` 和 `NJU8XXX_R2.fq.gz`;
#### 使用**FastQC**查看测序质量
```bash
fastqc NJU8XXX_R1.fq.gz NJU8XXX_R2.fq.gz
```
较新平台的测序系统（例如 `NovaSeq` ）对于质量分数存在调优，故质量过滤意义不大；
一般测序公司会提供初步质控后的Cleandata，可以直接使用；
#### 确保质量可靠后，对测序原始数据初步统计
```bash
pigz -dc NJU8XXX_R1.fq.gz NJU8XXX_R2.fq.gz |
    perl fastq2count.pl \
    >NJU8XXX.count
```
#### 根据采用的INDEX序列，准备INDEX文件
`index.txt` 文件内容形如：
```
ATCACG	ATCACG	ATCACG	ATCACG	CGATGT
ACAGTG	ACAGTG	ACAGTG	ACAGTG	GCCAAT
GACGAC	GACGAC	GACGAC	GACGAC	GTGGCC
CAGATC	CAGATC	CAGATC	CAGATC	ACTTGA
TTAGGC	TTAGGC	TTAGGC	TTAGGC	TGACCA
...
...
```
每行代表一组PCR产物，行数可自定；
每列分别为 `EGFR-19del` `EGFR-T790M` `EGFR-L858R` `KRAS-G12/13` `TP53-R175H`对应每组PCR的INDEX，相互采用制表符分隔；
#### 对野生型和突变型序列进行最后的统计
```bash
perl RBC.pl \
    index.txt \
    NJU8XXX.count \
    >NJU8XXX.txt
```
`NJU8XXX.txt` 内容为每种PCR产物的野生型和突变型统计，示例如下
```
4029        ### 代表第一组EGFR-19del的野生型reads数；
2           ### 代表第一组EGFR-19del的突变型reads数；
1456778     ### 代表第一组EGFR-T790M的野生型reads数；
0           ### 代表第一组EGFR-T790M的突变型reads数；
2393857     ### 代表第一组EGFR-L858R的野生型reads数；
1           ### 代表第一组EGFR-L858R的突变型reads数；
1098209     ### 代表第一组KRAS-G12/13的野生型reads数；
1197        ### 代表第一组KRAS-G12/13的突变型reads数；
745637      ### 代表第一组TP53-R175H的野生型reads数；
2           ### 代表第一组TP53-R175H的突变型reads数；

7057        ### 第二组由此开始
2
566736
751
1871968
1028
1061032
818
685042
360

1           ### 第三组由此开始
0
920922
865
2515331
3621
1230124
1485
1197746
1701

2           ### 第四组由此开始
0
684346
3667
2134690
10721
1060652
5452
725857
4220

0           ### 第五组由此开始
0
1964732
19525
1832544
3658
1089269
1550
1563726
7048
```