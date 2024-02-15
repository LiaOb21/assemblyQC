#!/usr/bin/env python3

# import libraries
import argparse
import pandas as pd
import gffpandas.gffpandas as gffpd

# define input files as they can be called from command line assigning a flag to each file
parser = argparse.ArgumentParser()
parser.add_argument("-a", "--asm_gff", help="assembly gff file")
parser.add_argument("-r", "--ref_gff", help="reference gff file")
parser.add_argument("-t", "--threshold", type=float, help="threshold for gene distance divergence")
args = parser.parse_args()
asm_gff = args.asm_gff
ref_gff = args.ref_gff
thresh = args.threshold


### process assembly gff file ###

def process_assembly_gff3(file_path):
    # Upload assembly gff file
    asm = gffpd.read_gff3(file_path)
    # Retain only gene features in assembly gff file
    gene_asm = asm.filter_feature_of_type(['gene']).to_tsv('temp_asm.tsv')
    gene_asm = pd.read_table('temp_asm.tsv')
    # Split attributes column into two columns
    gene_asm[['gene_id', 'attributes']] = gene_asm['attributes'].str.split(pat=';', expand=True, n=1)
    # Filter columns to retain only gene_id, seq_id, type, start, end, strand
    gene_asm_filt = gene_asm.filter(['seq_id', 'type', 'start', 'end', 'strand', 'gene_id'])
    # Calculate gene length and add 'asm' prefix to column names
    gene_asm_filt['gene_length'] = gene_asm_filt['end'] - gene_asm_filt['start']
    gene_asm_filt = gene_asm_filt.add_prefix('asm_')
    return gene_asm_filt

### process reference gff file ###

def process_ref_gff3(file_path):
    # upload reference gff file
    ref = gffpd.read_gff3(file_path)
    # retain only gene features in reference gff file
    gene_ref = ref.filter_feature_of_type(['gene']).to_tsv('temp_ref.tsv')
    # split attributes column into two columns
    gene_ref = pd.read_table('temp_ref.tsv')
    gene_ref[['gene_id', 'attributes']] = gene_ref['attributes'].str.split(pat=';', expand=True, n=1)
    # filter columns to retain only gene_id, seq_id, type, start, end, strand, attributes
    gene_ref_filt = gene_ref.filter(['seq_id', 'type', 'start', 'end', 'strand', 'gene_id', 'attributes'])
    # calculate gene length and add 'ref' prefix to column names
    gene_ref_filt['gene_length'] = gene_ref_filt['end'] - gene_ref_filt['start']
    gene_ref_filt = gene_ref_filt.add_prefix('ref_')
    return gene_ref_filt


### merge filtered reference and assembly gff files ###

def merge_ref_asm_gff(file_path1, file_path2, thresh):
    # call gff files processing functions
    gene_assembly_filt = process_assembly_gff3(file_path1)
    gene_reference_filt = process_ref_gff3(file_path2)
    # merge filtered reference and assembly gff files and sort by ref_seq_id and ref_start
    merged = pd.merge(gene_assembly_filt, gene_reference_filt, how="inner", left_on='asm_gene_id', right_on='ref_gene_id').sort_values(['ref_seq_id','ref_start'])
    # calculate distance between genes
    merged['asm_gene_distance'] = merged['asm_start'] - merged['asm_end'].shift(1)
    merged['ref_gene_distance'] = merged['ref_start'] - merged['ref_end'].shift(1)
    # find gene distance divergence assuming that the distance between genes in the reference is the same as in the assembly (or within a threshold)
    merged['gene_distance_divergence'] = ((merged['asm_gene_distance'] == merged['ref_gene_distance']) | (abs(merged['asm_gene_distance'] - merged['ref_gene_distance']) <= thresh))
    return merged

### split merged file into files, one for each chromosome ###

def split_by_chromosome(df):
    merged = df
    # get list of chromosomes
    chromosomes = merged['ref_seq_id'].unique()
    # split df into DataFrames, one for each chromosome
    dfs = {chromosome: merged[merged['ref_seq_id'] == chromosome] for chromosome in chromosomes}
    # save each DataFrame to a file
    for chromosome, df_chromosome in dfs.items():
        df_chromosome.to_csv('chr_' + chromosome + '.tsv', sep='\t', index=False)
    return dfs

### get output for each chromosome ###

def get_output(dfs):
    output_dfs = {}
    # process each DataFrame
    for chromosome, df in dfs.items():
        # group by ref_seq_id and asm_seq_id and calculate the number of genes - is each scaffold in asm corresponding to one chromosome in ref?
        df_output1 = df.groupby(['ref_seq_id', 'asm_seq_id']).size().reset_index(name='gene count')
        # group by ref_strand and asm_strand and calculate the count - are the genes in asm in reverse complement compared to the ref?
        df_output2 = df.groupby(['ref_strand', 'asm_strand']).size().reset_index(name='gene count')
        # calculate the percentage of genes in ascending and descending order in the assembly
        ascending = sum((df['asm_start'].iloc[i] < df['asm_start'].iloc[i+1]) for i in range(len(df['asm_start'])-1))
        descending = sum((df['asm_start'].iloc[i] > df['asm_start'].iloc[i+1]) for i in range(len(df['asm_start'])-1))
        total = len(df['asm_start']) - 1
        if total != 0:
            percentage_ascending = ascending / total * 100
            percentage_descending = descending / total * 100
        else:
            percentage_ascending = 0
            percentage_descending = 0
        # save files with divergent gene distance
        df_divergent = df[df['gene_distance_divergence'] == False]
        df_divergent.to_csv(f'divergent_chr_{chromosome}.tsv', sep='\t', index=False)
        # calculate how many genes have divergent gene distance
        df_output3 = df_divergent.groupby(['ref_seq_id', 'asm_seq_id']).size().reset_index(name='gene count')
        # save the output DataFrames to a text file with comments in between
        with open(f'output_chr_{chromosome}.txt', 'w') as f:
            f.write("# Is each scaffold in the assembly corresponding to one chromosome in the reference?\n")
            df_output1.to_csv(f, sep='\t', index=False)
            f.write("\n# Are the genes in the assembly in reverse complement compared to the reference?\n")
            df_output2.to_csv(f, sep='\t', index=False)
            f.write("\n# What is the percentage of genes in ascending and descending order in the assembly?\n")
            f.write(f"Percentage of genes in ascending order: {percentage_ascending}\n")
            f.write(f"Percentage of genes in descending order: {percentage_descending}\n")
            f.write("\n# How many genes have divergent gene distance between the assembly and the reference?\n")
            df_output3.to_csv(f, sep='\t', index=False)
        output_dfs[chromosome] = (df_output1, df_output2, df_output3)
    return output_dfs

if __name__ == "__main__":
    # call function to merge reference and assembly gff files
    merged = merge_ref_asm_gff(asm_gff, ref_gff, thresh)
    # save merged file as tsv
    merged.to_csv('merged.tsv', sep='\t', index=False)
    # split merged file into files, one for each chromosome
    dfs = split_by_chromosome(merged)
    # get output for each chromosome
    get_output(dfs)
