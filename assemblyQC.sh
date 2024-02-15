#!/bin/bash

# If any error occurs, exit
set -euo pipefail

# Print pipeline output to both terminal and .log file
log_file="assemblyQC_$(date +'%Y%m%d_%H%M%S').log"
exec > >(tee -a $log_file) 2>&1

# Initialize variables with default values when required (do not set default variables for -i, -l, -k, -r, -c, otherwise the help message won't work)
assemblies=""
conda_sh_path=""
quast_env="quast"
fragmented=""
large=""
busco_env="busco"
merqury_env="merqury"
liftoff_env="liftoff"  
merqury_path=""
busco_db=""
kmer_length=""
meryl_reads=""
reference_fasta=""
reference_gff=""
thresh="500"
Plt=""
Mt=""
threads="50"
run_liftoff=false
resume=false

# getopts to set the script flags 

while getopts ":i:c:q:b:m:p:l:d:k:r:f:g:s:a:e:t:oxywh" option; do
	case $option in
		i)
				assemblies="$OPTARG"
				echo "-i your input assemblies are: $assemblies/*"
				;;
		c)
				conda_sh_path="$OPTARG"
				echo "-c the path to your conda.sh file is: $conda_sh_path"
				;;
		q)
				quast_env="$OPTARG"
				echo "-q the name of your quast environment is: $quast_env"
				;;
		y)
				fragmented="--fragmented"
				echo "your reference genome is fragmented (-y). Adding --fragmented to quast command"
				;;
		w)
				large="--large"
				echo "your genome is large (-w). Adding --large to quast command"
				;;
		b)
				busco_env="$OPTARG"
				echo "-b the name of your busco environment is: $busco_env"
				;;
		m)
				merqury_env="$OPTARG"
				echo "-m the name of your merqury environment is: $merqury_env"
				;;
		p)
				merqury_path="$OPTARG"
				echo "-p the path to your merqury installation directory is: $merqury_path"
				;;
		l)	
				liftoff_env="$OPTARG"
				echo "-l the name of your liftoff environment is: $liftoff_env"
				;;
		d)
				busco_db="$OPTARG"
				echo "-l the lineage database you chose for busco is: $busco_db"
				;;
		k)	
				kmer_length="$OPTARG"
				echo "-k the kmer length you set for meryl database is: $kmer_length"
				;;
		r)	
				meryl_reads="$OPTARG"
				echo "-r the illumina/PacBio HiFi reads for meryl database you provided are: $meryl_reads/*"
				;;
		f)	
				reference_fasta="$OPTARG"
				echo "-f your reference fasta file for quast is: $reference_fasta"
				;;
		g)	
				reference_gff="$OPTARG"
				echo "-g your reference gff file for quast is: $reference_gff"
				;;
		s)	
				thresh="$OPTARG"
				echo "-s your threshold for finding gene distance divergence with liftoff_combine.py is: $thresh"
				;;
		a)	
				Plt="$OPTARG"
				echo "-a the header of the plastidial genome is: $Plt"
				;;
		e)	
				Mt="$OPTARG"
				echo "-e the header of the mitochondrial genome is: $Mt"
				;;
		t)	
				threads="$OPTARG"
				echo "-t the numner of threads for processing is: $threads"
				;;
		o)		
				run_liftoff=true
				echo "-o you chose to run liftoff and liftoff_combine.py to evaluate your assembly based on gene position"
				;;
		x)	
				resume=true
				echo "-x you chose to resume pipeline from last step"
				;;			
		h)
					echo "Usage: $0 -i <assemblies_directory> -c <conda_sh_path> -q <quast_env> -b <busco_env> -m <merqury_env> -p <merqury_path> -l <liftoff_env> -d <busco_db> -k <kmer_length> -r <meryl_reads> [-f <reference_fasta>] [-g <reference_gff>] -s <thresh> -a <Plt> -e <Mt> -t <threads>"
					echo "Options:"
					echo "	-i <assemblies_directory>	:	put all the assemblies in one directory and enter the path/to/your/assemblies" 
					echo "	-c <conda_sh_path>	:	/path/to/your/miniconda-anaconda/installation/directory/etc/profile.d/conda.sh. You must put the link to conda.sh that is contained in etc/profile.d"
					echo "	-q <quast_env>	:	Name of your quast environment. Default: quast"
					echo "	-y <fragmented>	:	set -y  to add --fragmented to quast command if your reference genome is fragmented. Default: false"
					echo "	-w <large>	:	set -w  to add --large to quast command if your genome is large. Default: false"
					echo "	-b <busco_env>	:	Name of your busco environment. Default: busco"
					echo "	-m <merqury_env>	:	Name of your merqury environment. Default: merqury"
					echo "	-p <merqury_path>	:	/path/to/your/merqury/installation/directory."
					echo "	-l <liftoff_env>	:	Name of your liftoff environment. Default: liftoff"
					echo "	-d <busco_db>	:	Busco lineage database you want to use. Must be downloaded from https://busco-data.ezlab.org/v5/data/lineages/ before of running the pipeline. Enter here the path/to/lineagedb"
					echo "	-k <kmer_length>	:	Used by meryl to build the database. If unsure of the length of the kmers, run best_k.sh (merqury function) first, using genome size in bp"
					echo "	-r <meryl_reads>	:	Used by meryl to build the database. They can be illumina or PacBio HiFi reads. Illumina are preferred. Enter here the path/to/your/reads" 
					echo "	[-f <reference_fasta>]	:	 Path to the reference FASTA file. Used by quast to compute statistics (optional). Required if you want to run liftoff." 
					echo "	[-g <reference_gff>]	:	Path to the reference GFF file. Used by quast to compute statistics (optional). Required if you want to run liftoff."
					echo "	-s <thresh>	:	Threshold in bp for finding gene distance divergence with liftoff_combine.py. Default: 500"
					echo "	-a <Plt>	:	Header of the chloroplast genome. Used to remove organelles genome information from the reference gff before running liftoff. Leave empty if you don't have a chloroplast genome or if you want to include it in the analysis."
					echo "	-e <Mt>	:	Header of the mitochondrial genome. Used to remove organelles genome information from the reference gff before running liftoff. Leave empty if you don't have a mitochondrial genome or if you want to include it in the analysis."
					echo "	-t <threads>	:	Number of threads for processing. Default: 50"
					echo "	<-o run_liftoff>	:	Run liftoff and liftoff_combine.py to evaluate your assembly based on gene position. Default: false (skip this step)"
					echo "	<-x resume>	:	Resume pipeline from last step (i.e. skip steps that are already completed if the pipeline was interrupted). Default: false (start from the beginning)"
					echo "	<-h help>	:	Show help message and exit"
					exit 0
        ;;
		\?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
        ;;
		:)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
        ;;
	esac
done


##############################################################

# making flags mandatory and setting error messages

# Check if the value for assemblies has been provided
if [ -z "$assemblies" ]; then
    echo " Error: No value provided for the -i (assemblies) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if assemblies directory exists
if [ ! -d "$assemblies" ]; then
    echo "Error: Assembly directory '$assemblies' does not exist! Type '$0 -h' for help."
    exit 1
fi

# Check if the path to conda.sh has been provided
if [ -z "$conda_sh_path" ]; then
    echo "Error: No value provided for the -c (path/to/conda.sh) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if the path to merqury has been provided
if [ -z "$merqury_path" ]; then
    echo "Error: No value provided for the -p (path/to/merqury) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if the value for busco database has been provided
if [ -z "$busco_db" ]; then
    echo "Error: No value provided for the -d (busco lineage) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if busco database directory exists
if [ ! -d "$busco_db" ]; then
    echo "Error: Busco lineage database directory '$busco_db' does not exist! Type '$0 -h' for help."
    exit 1
fi


# Check if the value for kmer length (used by meryl) has been provided
if [ -z "$kmer_length" ]; then
    echo "Error: No value provided for the -k (kmer_length) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if the value for illumina or PacBio HiFi reads (used by meryl) has been provided
if [ -z "$meryl_reads" ]; then
    echo "Error: No value provided for the -r (illumina or PacBio HiFi reads) option. It is mandatory. Type '$0 -h' for help."
    exit 1
fi

# Check if reads directory exists
if [ ! -d "$meryl_reads" ]; then
    echo "Error: Reads directory '$meryl_reads' does not exist! Type '$0 -h' for help."
    exit 1
fi

# Make sure that the provided number of threads is a positive
if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
    echo "Error: '$threads' is not a valid number of threads. Please provide a positive integer."
    exit 1
elif [ "$threads" -le 0 ]; then
    echo "Error: The number of threads should be a positive integer."
    exit 1
fi

# Make sure that the provided threshold is a positive
if ! [[ "$thresh" =~ ^[0-9]+$ ]]; then
	echo "Error: '$thresh' is not a valid threshold. Please provide a positive integer."
	exit 1
elif [ "$thresh" -le 0 ]; then
	echo "Error: The threshold should be a positive integer."
	exit 1
fi

# Make mandatory the value for reference fasta and gff when -o is passed
if [ "$run_liftoff" == true ]; then
    if [ -z "$reference_fasta" ] || [ -z "$reference_gff" ]; then
        echo "Error: -f and -g are required when -o is passed. This are mandatory inputs for liftoff. Type '$0 -h' for help."
        exit 1
    fi
fi

##############################################################


# Function to check if a step is completed - allows to resume the pipeline
is_step_completed() {
    local step=$1
    [ -f completed_steps.log ] && grep -q "$step" completed_steps.log
}



# --- Quast Step ---

quast_func() {
    if [ "$resume" == true ] && is_step_completed "quast"; then
        echo "Quast is already completed. Skipping..."
        return
    fi

	# activate conda environment
	conda activate $quast_env

	# launch quast
	if [[ -n $reference_fasta && -n $reference_gff ]]; then
    	echo "Running Quast... (with reference fasta and gff)"
		echo "quast $assemblies/*.fasta -o quast -r $reference_fasta -g $reference_gff -t $threads $fragmented $large"
		quast $assemblies/*.fasta -o quast -r $reference_fasta -g $reference_gff -t $threads $fragmented $large
	elif [[ -n $reference_fasta ]]; then
		echo "Running Quast... (with reference fasta)"
		echo "quast $assemblies/*.fasta -o quast -r $reference_fasta -t $threads $fragmented $large"
		quast $assemblies/*.fasta -o quast -r $reference_fasta -t $threads $fragmented $large
	elif [[ -n $reference_gff && -z $reference_fasta ]]; then
		echo "ERROR: if you provide a reference gff you must also provide a reference fasta"
	else
		echo "Running Quast... (without reference)"
		echo "quast $assemblies/*.fasta -o quast -t $threads $large"
		quast $assemblies/*.fasta -o quast -t $threads $large
	fi
	# deactivate conda environment
	conda deactivate

    echo "quast" >> completed_steps.log
}


# --- Busco Step ---

busco_func() {
    if [ "$resume" == true ] && is_step_completed "busco"; then
        echo "Busco is already completed. Skipping..."
        return
    fi


	# activate busco environment
	conda activate $busco_env

	# create a directory from where to launch busco and move into it
	mkdir -p busco
	cd busco

	# launch busco
    echo "Running Busco..."
	for i in $assemblies/*.fasta; do
		#extract assemblies names
		assembly_name=$(basename $i)
		#print single commands
		echo "busco -i $i -o ${assembly_name}_busco -m genome -l $busco_db -f -c $threads"
		# run busco on each assembly
		busco -i $i -o ${assembly_name}_busco -m genome -l $busco_db -f -c $threads
	done

	# deactivate conda environment
	conda deactivate

	# go back to assembly_QC_out
	cd ..

    echo "busco" >> completed_steps.log
}



# --- Merqury Step ---

merqury_func() {
    if [ "$resume" == true ] && is_step_completed "merqury"; then
        echo "Merqury is already completed. Skipping..."
        return
    fi


	# activate merqury environment
	conda activate $merqury_env

	# create a directory from where to launch merqury and move into it
	mkdir -p merqury
	cd merqury

	# obtain meryl database "meryl_db"
	echo "meryl k=$kmer_length count $meryl_reads/* output read-db.meryl threads=$threads"
	meryl k=$kmer_length count $meryl_reads/* output read-db.meryl threads=$threads

	# launch merqury
    echo "Running Merqury..."
	for i in $assemblies/*.fasta; do
		# extract assemblies names
		assembly_name=$(basename $i)
		# create a directory for each assembly
		mkdir -p ${assembly_name}_merqury
		# move into each assembly directory
		cd ${assembly_name}_merqury
		# print single commands
		echo "$MERQURY/merqury.sh ../read-db.meryl/ ${i} ${assembly_name}_merqury"
  	    # export merqury path again to avoid problems (sometimes if executing the pipeline in screen mode it doesn't work if you don't export the path)
	    export MERQURY=$merqury_path      
		# run merqury on each assembly
		"$MERQURY/merqury.sh" ../read-db.meryl/ ${i} ${assembly_name}_merqury
		# go back to merqury directory
		cd ..
	done

	# deactivate conda environment
	conda deactivate

	# go back to assembly_QC_out
	cd ..

    echo "merqury" >> completed_steps.log
}


# --- Liftoff Step ---

liftoff_func() {
    if [ "$resume" == true ] && is_step_completed "liftoff"; then
        echo "Liftoff is already completed. Skipping..."
        return
    fi


	# activate busco environment
	conda activate $liftoff_env

	# create a directory from where to launch liftoff and move into it
	mkdir -p liftoff
	cd liftoff

	# remove organelles from reference gff
	echo "Removing organelles from reference gff..."
	awk -v plt="$Plt" -v mt="$Mt" '$1 != plt && $1 != mt' $reference_gff > filtered_ref_annotation.gff

	# launch liftoff
    echo "Running Liftoff..."
	for i in $assemblies/*.fasta; do
		# extract assemblies names
		assembly_name=$(basename $i)
		# create a directory for each assembly
		mkdir -p ${assembly_name}_liftoff
		# move into each assembly directory
		cd ${assembly_name}_liftoff
		# print single commands
		echo "liftoff $i $reference_fasta -g ../filtered_ref_annotation.gff -o ${assembly_name}_liftoff_out.gff3 -exclude_partial"
		# run busco on each assembly
		liftoff $i $reference_fasta -g $reference_gff -o ${assembly_name}_liftoff_out.gff3 -exclude_partial
		# run liftoff_combine.py
		echo "python3 ../../../liftoff_combine.py -a ${assembly_name}_liftoff_out.gff3 -r ../filtered_ref_annotation.gff -t $thresh"
		python3 ../../../liftoff_combine.py -a ${assembly_name}_liftoff_out.gff3 -r ../filtered_ref_annotation.gff -t $thresh
		# go back to liftoff directory
		cd ..		
	done

	# deactivate conda environment
	conda deactivate

	# go back to assembly_QC_out
	cd ..

    echo "liftoff" >> completed_steps.log
}

# --- Main Function ---

main() {
    # Print start message
    echo -e "\n"
    echo "Starting assemblyQC at $(date)"
    echo -e "\n"

	# initial set up
    # create a directory from where to launch the pipeline and move into it
	mkdir -p assembly_QC_out
	cd assembly_QC_out
	# export conda functions
	source $conda_sh_path

    # Call each step
    quast_func 
    busco_func 
    merqury_func 
	if [ "$run_liftoff" == true ]; then
    liftoff_func 
  	fi

    # Print end message
    echo -e "\n"
    echo "Finishing assemblyQC at $(date). Thank you, bye!"
}

# --- Call main function ---

if [[ "$resume" == "true" ]]; then
	echo "Resuming pipeline..."
	main "--resume"
else
	echo "Starting pipeline..."
	main "--no-resume"
fi