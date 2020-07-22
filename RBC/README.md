# Workflow
## PCR产物测序结果突变检测流程
#### 测序结果文件
`NJU8XXX_R1.fq.gz` 和 `NJU8XXX_R1.fq.gz`;
#### 使用**FastQC**查看测序质量
```bash
fastqc NJU8XXX_R1.fq.gz NJU8XXX_R1.fq.gz
```
#### 确保质量可靠后，对测序原始数据初步统计
```bash
pigz -dc NJU8XXX_R1.fq.gz NJU8XXX_R2.fq.gz | perl fastq2count.pl > NJU8XXX.count
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
每行代表一组PCR产物；
每列分别为 `EGFR-19del` `EGFR-T790M` `EGFR-L858R` `KRAS-G12/13` `TP53-R175H`对应每组PCR的INDEX；
#### 对野生型和突变型序列进行最后的统计
```bash
perl RBC.pl index.txt NJU8XXX.count > NJU8XXX.txt
```
`NJU8XXX.txt` 内容为每种PCR产物的野生型和突变型统计