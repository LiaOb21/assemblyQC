[![DOI](https://zenodo.org/badge/715096495.svg)](https://zenodo.org/doi/10.5281/zenodo.10666785)

# assemblyQC

<p align="center">
  <img src="https://github.com/LiaOb21/assemblyQC/assets/96196229/a1cb5bef-e9b8-4bad-a6b8-2a864d174f61" />
</p>

`assemblyQC` is a bash pipeline that allows you to run several quality checks on one or a bunch of assemblies in one go!

This pipeline combines:
- [quast](https://github.com/ablab/quast) for evaluating genome assemblies by computing various metrics;
- [busco](https://github.com/WenchaoLin/BUSCO-Mod) for assessing genome assembly and annotation completeness with Benchmarking Universal Single-Copy Orthologs;
- [merqury](https://github.com/marbl/merqury) for estimating genome completeness and accuracy by using k-mer frequencies.

It also optionally runs [liftoff](https://github.com/agshumate/Liftoff) and a python script called `liftoff_combine.py` that allows you to evaluate your assembly based on the gene position on your assembly compared to a reference genome. 

The pipeline is intended to benchmark several assemblies obtained with different assembly strategies but obtained from the same raw data.

# Set up of the environment and dependencies

To be able to run the pipeline you must set up your environment first. You must install several packages with conda, so make sure to have conda installed in your system. [Here](https://docs.conda.io/projects/conda/en/latest/user-guide/install/linux.html) you can find how to install conda on your system.

## quast installation
Once you've installed conda, you must install quast creating a new environment as follows:

```
conda create -n quast -c bioconda quast 
conda activate quast
quast-download-gridss
quast-download-silva
quast-download-busco
```

If you already have a quast environment on your system and you gave it a different name, you can specify the name of your quast environment to `assemblyQC.sh` passing the flag `-q your_quast_env_name`. 

If you need more information about quast you can find it [here](https://github.com/ablab/quast).

## busco installation

Once you've installed conda, you must install busco creating a new environment as follows:

```
conda create -n busco -c conda-forge -c bioconda busco=5.5.0 
```
If you already have a busco environment on your system and you gave it a different name, you can specify the name of your busco environment to `assemblyQC.sh` passing the flag `-b your_busco_env_name`.

In order to run busco, you will also need to download the database of the lineage of your interest from: https://busco-data.ezlab.org/v5/data/lineages/. The path to your database of interest must be given to `assemblyQC.sh` with the flag `-d path/to/lineagedb`.

If you need more information about busco, you can find it [here](https://github.com/WenchaoLin/BUSCO-Mod).


## merqury installation

Once you've installed conda, you must follow these steps to create a merqury environment:

```
conda create -n merqury -c conda-forge gxx
conda activate merqury
conda install -c bioconda merqury -y
conda remove --force merqury
```

Here we are creating an environment containing all the dependencies of merqury, and removing the merqury conda package itself from the environment. The merqury package in bioconda is at the moment not updated, therefore you need to install it locally cloning its repository from github:

```
git clone https://github.com/marbl/merqury.git
```

If you need more information about merqury, you can find it [here](https://github.com/marbl/merqury).


### meryl installation

Meryl is required in order to run merqury. 
```
mkdir meryl
cd meryl
wget https://github.com/marbl/meryl/releases/download/v1.4.1/meryl-1.4.1.Linux-amd64.tar.xz
tar -xJf meryl-1.4.1.Linux-amd64.tar.xz
```

If you need more information about meryl, you can find it [here](https://github.com/marbl/meryl).

Once you have installed merqury and meryl, you must export their paths:
```
export MERQURY="/path/to/merqury"
export PATH="$MERQURY:$PATH"
export PATH="/path/to/meryl/meryl-1.4.1/bin:$PATH"
```

If you already have a working merqury **version** environment on your system and you gave it a different name, you can specify the name of your merqury environment to `assemblyQC.sh` passing the flag `-m your_merqury_env_name`. 

Another requirement of the pipeline is to provide the length of kmers to produce the meryl database. This information can be given with the flag `-k length`. If unsure of what kmer length to use, you can run the merqury function `best_k.sh` with `genome_size` in number of bp.

**N.B. This pipeline supports the merqury case in which one assembly with no hap-mers is provided: https://github.com/marbl/merqury#1-i-have-one-assembly-pseudo-haplotype-or-mixed-haplotype**

## liftoff installation

Once you've installed conda, you must install liftoff creating a new environment as follows:

```
conda create -n liftoff -c bioconda liftoff
```

We also need to install some python libraries that are not installed automatically within the liftoff environment:

```
conda activate liftoff
pip install pandas
pip install gffpandas
```

If you already have a liftoff environment on your system and you gave it a different name, you can specify the name of your liftoff environment to `assemblyQC.sh` passing the flag `-l your_liftoff_env_name`. Remember anyway to install the python libraries `pandas` and `gffpandas` within the liftoff environment.

If you need more information about liftoff you can find it [here](https://github.com/agshumate/Liftoff).

# Installation

To tun `assemblyQC` you only need to clone the github repository:

```
git clone https://github.com/LiaOb21/assemblyQC.git
cd assemblyQC/
```

Print the help message to get help on how to run `assemblyQC`:
```
Usage: ./assemblyQC.sh -i <assemblies_directory> -c <conda_sh_path> -q <quast_env> -b <busco_env> -m <merqury_env> -p <merqury_path> -l <liftoff_env> -d <busco_db> -k <kmer_length> -r <meryl_reads> [-f <reference_fasta>] [-g <reference_gff>] -s <thresh> -a <Plt> -e <Mt> -t <threads>
Options:
        -i <assemblies_directory>       :       put all the assemblies in one directory and enter the path/to/your/assemblies
        -c <conda_sh_path>      :       /path/to/your/miniconda-anaconda/installation/directory/etc/profile.d/conda.sh. You must put the link to conda.sh that is contained in etc/profile.d
        -q <quast_env>  :       Name of your quast environment. Default: quast
        -y <fragmented> :       set -y  to add --fragmented to quast command if your reference genome is fragmented. Default: false
        -w <large>      :       set -w  to add --large to quast command if your genome is large. Default: false
        -b <busco_env>  :       Name of your busco environment. Default: busco
        -m <merqury_env>        :       Name of your merqury environment. Default: merqury
        -p <merqury_path>       :       /path/to/your/merqury/installation/directory.
        -l <liftoff_env>        :       Name of your liftoff environment. Default: liftoff
        -d <busco_db>   :       Busco lineage database you want to use. Must be downloaded from https://busco-data.ezlab.org/v5/data/lineages/ before of running the pipeline. Enter here the path/to/lineagedb
        -k <kmer_length>        :       Used by meryl to build the database. If unsure of the length of the kmers, run best_k.sh (merqury function) first, using genome size in bp
        -r <meryl_reads>        :       Used by meryl to build the database. They can be illumina or PacBio HiFi reads. Illumina are preferred. Enter here the path/to/your/reads
        [-f <reference_fasta>]  :        Path to the reference FASTA file. Used by quast to compute statistics (optional). Required if you want to run liftoff.
        [-g <reference_gff>]    :       Path to the reference GFF file. Used by quast to compute statistics (optional). Required if you want to run liftoff.
        -s <thresh>     :       Threshold in bp for finding gene distance divergence with liftoff_combine.py. Default: 500
        -a <Plt>        :       Header of the chloroplast genome. Used to remove organelles genome information from the reference gff before running liftoff. Leave empty if you don't have a chloroplast genome or if you want to include it in the analysis.
        -e <Mt> :       Header of the mitochondrial genome. Used to remove organelles genome information from the reference gff before running liftoff. Leave empty if you don't have a mitochondrial genome or if you want to include it in the analysis.
        -t <threads>    :       Number of threads for processing. Default: 50
        <-o run_liftoff>        :       Run liftoff and liftoff_combine.py to evaluate your assembly based on gene position. Default: false (skip this step)
        <-x resume>     :       Resume pipeline from last step (i.e. skip steps that are already completed if the pipeline was interrupted). Default: false (start from the beginning)
        <-h help>       :       Show help message and exit
```

Here's a brief description of each argument:

- `-i`: Path to the directory containing all the assemblies.
- `-c`: Path to the `conda.sh` file in your Miniconda or Anaconda installation.
- `-q`: Name of your Quast environment. Default is `quast`.
- `-y`: (Optional) Must be set when the reference genome (`-f`) is fragmented.
- `-w`: (Optional) Must be set when the genome to analyse is large.
- `-b`: Name of your Busco environment. Default is `busco`.
- `-m`: Name of your Merqury environment. Default is `merqury`.
- `-p`: Path to your Merqury installation directory.
- `-l`: Name of your Liftoff environment.
- `-d`: Path to the Busco lineage database you want to use.
- `-k`: K-mer length for building the Meryl database.
- `-r`: Path to the reads used by Meryl to build the database. These can be Illumina or PacBio HiFi reads.
- `-f`: (Optional) Path to the reference FASTA file. Used by Quast to compute statistics. Required if you want to run Liftoff.
- `-g`: (Optional) Path to the reference GFF file. Used by Quast to compute statistics. Required if you want to run Liftoff.
- `-s`: Threshold in base pairs for finding gene distance divergence with `liftoff_combine.py`. Default is 500. 
- `-a`: Header of the chloroplast genome. Used to remove organelles genome information from the reference gff before running liftoff. Do not use this flag if you don't have a chloroplast genome or if you want to include it in the analysis.
- `-e`: Header of the mitochondrial genome. Used to remove organelles genome information from the reference gff before running liftoff. Do not use this flag if you don't have a mitochondrial genome or if you want to include it in the analysis.
- `-t`: Number of threads for processing. Default is 50.
- `-o`: If set, run Liftoff and `liftoff_combine.py` to evaluate your assembly based on gene position. Default is to skip this step.
- `-x`: If set, resume pipeline from the last step (useful if the pipeline was interrupted). Default is to start from the beginning.
- `-h`: Show help message and exit.

Each argument is followed by a value (e.g., `-i <assemblies_directory>`), except for `-o`, `-x`, and `-h`, which are flags and don't require a following value.

**IMPORTANT:**

- You must create a directory containing only the assemblies you want to process with this pipeline. All the assembly files must have `.fasta` as extension. The path to this directory must be passed to the `-i` flag. The format of path to this directory must be `/path/to/your/assemblies_directory`. Please **do not** type `/` or `/*` at the end of the path.
- You must create a directory containing only the reads that you want to use to create the meryl database. The path to this directory must be passed to the `-r` flag. Please **do not** type `/` or `/*` at the end of the path.
- The liftoff step is optional. If you want to run this step you must pass the `-o` flag in your command. This step is recommended only in the case in which you have a reference genome `.fasta` and `.gff` file of the same species or closely related species to the assemblies you want to process.
- unzip the reference `.fasta` and `.gff` files if they are zipped.
- The liftoff step includes a python script called `liftoff_combine.py` that is not part of liftoff itself. This script provides several metrics to evaluate the assembly accuracy in terms of gene order and positioning. To run, this script needs a threshold to identify gene distance divergence, passed to `assemblyQC` with the flag `-s`. The default is 500 bp, meaning that the divergence in gene distance below 500 bp is not considered.
- Keep the flags' order as shown in the help message

# Run assemblyQC

Assuming that we are working with *Arabidopsis thaliana* data, and that we have these settings:

- directory containing input assemblies: /home/usr/assemblies
- path to `conda.sh` file: /home/usr/software/miniconda3/etc/profile.d/conda.sh
- `quast` environment name: quast
- `busco` environment name: busco
- `merqury` environment name: merqury
- `merqury` installation path: /home/usr/software/merqury
- `liftoff` environment name: liftoff
- path to busco lineage database: /home/usr/Arabidopsis/busco_comp/brassicales_odb10
- kmer length for meryl database: 18
- path to illumina/PacBio HiFi reads for meryl database: /home/usr/Arabidopsis/illumina
- reference `.fasta` file: /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.fna
- reference `.gff` file: /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.gff
- header of plastid genome: `AP000423.1`
- header of mitochondrial genome: `BK010421.1`
- threshold for finding gene distance divergence with liftoff_combine.py: 500

Here the file system explained above:
```
/home
└── usr
    ├── assemblies
    ├── software
    │   ├── miniconda3
    │   │   └── etc
    │   │       └── profile.d
    │   │           └── conda.sh
    │   └── merqury
    ├── Arabidopsis
    │   ├── busco_comp
    │   │   └── brassicales_odb10
    │   ├── illumina
    │   └── reference
    │       ├── GCA_000001735.2_TAIR10.1_genomic.fna
    │       └── GCA_000001735.2_TAIR10.1_genomic.gff
```

N.B. The file system structure doesn't have to be exactly the same as long as you provide the files and paths as explained.

`assemblyQC` can be run in one of the following ways:

## 1. I don't have a reference genome

If you don't have a reference genome, you can still run `quast` that in this case will not compute the statistics against the reference. In this case you cannot run `liftoff`, so you must not use the `-o` flag in your command:

```
./assemblyQC.sh \
-i /home/usr/assemblies \
-c /home/usr/software/miniconda3/etc/profile.d/conda.sh \
-q quast \
-b busco \
-m merqury \
-p /home/usr/software/merqury \
-l liftoff \
-d /home/usr/Arabidopsis/busco_comp/brassicales_odb10 \
-k 18 \
-r /home/usr/Arabidopsis/illumina \
-t 20 \
```

## 2. I have a reference genome (`.fasta` and `.gff` files) but I don't want to run the liftoff step

In this case you can use your reference `.fasta` and `.gff` files with the `-f` and `-g` flag respectively for running `quast`, but you should not use the `-o` flag in order to avoid running liftoff.

```
./assemblyQC.sh \
-i /home/usr/assemblies \
-c /home/usr/software/miniconda3/etc/profile.d/conda.sh \
-q quast \
-b busco \
-m merqury \
-p /home/usr/software/merqury \
-l liftoff \
-d /home/usr/Arabidopsis/busco_comp/brassicales_odb10 \
-k 18 \
-r /home/usr/Arabidopsis/illumina \
-f /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.fna \
-g /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.gff \
-t 20 \
```

## 3. I have a reference genome (`.fasta` and `.gff` files) and I want to run the liftoff step

In this case you must use the `-o` flag, which enables the `liftoff` step, and you should indicate a threshold for the gene distance divergence calculation using `-s` (default:500 bp). Moreover, if you wish to remove plastid and mitochondrial genomes from the analysis, you should indicate their headers using `-a` and `-e` respectively:

```
./assemblyQC.sh \
-i /home/usr/assemblies \
-c /home/usr/software/miniconda3/etc/profile.d/conda.sh \
-q quast \
-b busco \
-m merqury \
-p /home/usr/software/merqury \
-l liftoff \
-d /home/usr/Arabidopsis/busco_comp/brassicales_odb10 \
-k 18 \
-r /home/usr/Arabidopsis/illumina \
-f /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.fna \
-g /home/usr/Arabidopsis/reference/GCA_000001735.2_TAIR10.1_genomic.gff \
-s 500 \
-a AP000423.1
-e BK010421.1
-t 20 \
-o 
```

If you don't have plastid and mitochondrial genome, or if you want to include them in the analysis, do not use the `-a` and `-e` flags.

## 4. Resuming the pipeline if it failed at some point

In this case you can give the same command as the above cases, but you must add the `-x` flag. Please note that in case you want to resume the pipeline and run the liftoff step you must add both `-x` and `-o` to your command.


# Output

Once the pipeline is completed successfully, your results will be in the `assemblyQC/assembly_QC_out` directory.
The outputs will be stored in a different directory for each tool: quast, busco, merqury, liftoff.
Within the busco, merqury and liftoff directories, you will find one directory per inputted assembly:


```
assemblyQC/
└── assembly_QC_out/
	├── quast/
	├── busco/
	│   ├── assembly1/
	│   ├── assembly2/
	│   └── ...
	├── merqury/
	│   ├── assembly1/
	│   ├── assembly2/
	│   └── ...
	└── liftoff/
		├── assembly1/
		├── assembly2/
		└── ...
```

For information about QUAST outputs refer to [QUAST manual](https://quast.sourceforge.net/docs/manual.html). \
For information about BUSCO outputs refer to [BUSCO user guide](https://busco.ezlab.org/busco_userguide.html#citation).\
For information about Merqury outputs refer to [Merqury wiki](https://github.com/marbl/merqury/wiki/2.-Overall-k-mer-evaluation).\
For information about Liftoff outputs refer to [Liftoff github page](https://github.com/agshumate/Liftoff).

**explain in detail the output of `liftoff_combine.py`**

Within the `assembly_QC_out/liftoff/your_assembly_liftoff` directory you will find several files:

- `your_assembly_liftoff_out.gff3`, `unmapped_features.txt`, and the directory `intermediate_files` are outputs of Liftoff itself, for which you should refer to the Liftoff page.
- `temp_ref.tsv` and `temp_asm.tsv` are intermediate files produced by `liftoff_combine.py`.
- `merged.tsv` is an output of `liftoff_combine.py`, which is the union of the `.gff` of the reference and the `.gff` og the assembly. The fields with the `asm` prefix refer to the assembly, while the fields with the `ref` prefix refer to the reference.
- `liftoff_combine.py` produces a series of files called `chr_*.tsv`. These are subset of `merged.tsv`, one for each reference chromosome.
- `liftoff_combine.py` produces a series of files called `divergent_chr_*.tsv`, one for each reference chromosome, where you can find the list of the genes that show divergent gene distance in the assembly compared to the reference. N.B.: these output may differ according to what threshold you set with `-s` in your command. If you are using the default settings, if the gene distance divergence between the assembly and the reference is greater than 500 bp, the gene will be stored in this file.
- Finally, `liftoff_combine.py` produces a series of files called `output_chr_*.txt`, one for each reference chromosome, where a summary statistics is stored. These files look like this:

```
# Is each scaffold in the assembly corresponding to one chromosome in the reference?
ref_seq_id      asm_seq_id      gene count
CP002684.1      ptg000007l_1    8738

# Are the genes in the assembly in reverse complement compared to the reference?
ref_strand      asm_strand      gene count
+       +       4443
+       -       4
-       +       1
-       -       4290

# What is the percentage of genes in ascending and descending order in the assembly?
Percentage of genes in ascending order: 99.50784021975507
Percentage of genes in descending order: 0.2060203731257869

# How many genes have divergent gene distance between the assembly and the reference?
ref_seq_id      asm_seq_id      gene count
CP002684.1      ptg000007l_1    56
```

This file gives several information:
- The reference chromosome `CP002684.1` correspond only to one contig/scaffold in the assembly, which is `ptg000007l_1`. The total number of genes shared by the reference and the assembly for this chromosome is `8738`.
- When `ref_strand` = `asm_strand`, the genes in the assembly are in the same orientation as in the reference. This information combined with the percentage of genes in ascending/descending order allows to understand if the chromosome is in the same orientation of the reference or if it is in reverse complement. \
When for the majority of the genes `ref_strand` = `asm_strand` and the percentage of genes in ascending order > 90%, we are quite sure that the assembly has the same orientation of the reference for this chromosome. \
On the other hand, when for the majority of genes we see a + for `ref_strand` and a - for `ams_strand` (or vice versa), and the percentage of genes in descending order is > 90%, we are quite sure that the assembly is in reverse complement compared to the reference for this chromosome. \
When a contig/scaffold in the assembly is in reverse complement compared to the reference, this must not considered as an error. \
In some cases the result is not really clear and the amount of genes in the same orientation as the reference is similar to the amount of genes in reverse complement. In this case there can be issues in the assembly process, or the assembly needs to be manually curated. 
- The number of genes that in the assembly show divergent gene distance compared to the reference are in this case `56`. These 56 genes are stored in the correspondent `divergent_chr_*.tsv`, and can be further investigated.


# Citation

 If you use `assemblyQC` in your work, please cite:

 - **For QUAST:** Alla Mikheenko, Andrey Prjibelski, Vladislav Saveliev, Dmitry Antipov, Alexey Gurevich, Versatile genome assembly evaluation with QUAST-LG, Bioinformatics, Volume 34, Issue 13, July 2018, Pages i142–i150, https://doi.org/10.1093/bioinformatics/bty266

 - **For BUSCO:** Mosè Manni, Matthew R Berkeley, Mathieu Seppey, Felipe A Simão, Evgeny M Zdobnov, BUSCO Update: Novel and Streamlined Workflows along with Broader and Deeper Phylogenetic Coverage for Scoring of Eukaryotic, Prokaryotic, and Viral Genomes. Molecular Biology and Evolution, Volume 38, Issue 10, October 2021, Pages 4647–4654

 - **For Merqury and Meryl:** Rhie, A., Walenz, B.P., Koren, S. et al. Merqury: reference-free quality, completeness, and phasing assessment for genome assemblies. Genome Biol 21, 245 (2020). https://doi.org/10.1186/s13059-020-02134-9
 
 - **For Liftoff:** Shumate, Alaina, and Steven L. Salzberg. 2020. “Liftoff: Accurate Mapping of Gene Annotations.” Bioinformatics , December. https://doi.org/10.1093/bioinformatics/btaa1016.

 - **For assemblyQC:** Lia Obinu, Urmi Trivedi, Andrea Porceddu, 2023. "Benchmarking of Hi-C tools for scaffolding de novo genome assemblies". bioRxiv 2023.05.16.540917; doi: https://doi.org/10.1101/2023.05.16.540917
