##########################
## execution example
## export mydir=/shared/homes/12705859/hackflex_libs/ecoli/main
## export ref_genome=/shared/homes/12705859/hackflex_libs/ecoli/main/assembly.fasta
## qsub -V 002_library_mapping.sh
##########################

#!/bin/bash
#PBS -l ncpus=10
#PBS -l walltime=10:00:00
#PBS -l mem=10g
#PBS -N 002_library_mapping
#PBS -M daniela.gaio@student.uts.edu.au

source activate py_3.5

cd $mydir


# index the reference genome
bwa index $ref_genome


# map interleaved clean library to reference genome
for library in `ls reduced*`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
bwa mem -p $ref_genome $library > $lib.sam # S. aureus to be replaced with $ref_genome
done


# create .bam
for library in `ls *.sam`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
samtools view -Sb $library | samtools sort -o $lib.bam
done


# samtools index and sort:
for library in `ls *.bam`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
samtools index $library
samtools sort -n -o $lib.namesort $library
done


# samtools fixmate:
for library in `ls *.namesort`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
samtools fixmate -m $library $lib.fixmate
done


# samtools re-sort:
for library in `ls *.fixmate`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
samtools sort -o $lib.positionsort $library
done


# samtools remove dups:
rm dups_stats.txt
for library in *.positionsort ;
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
echo "##############" >> dups_stats.txt
echo $lib >> dups_stats.txt
samtools markdup -r -s $library $lib.dedup.bam &>> dups_stats.txt
done


# run flagstat & save output 
rm flagstat_out*
for file in `ls *.dedup.bam`
do
filename=$(basename $file)
N="${filename%.*}"
samtools flagstat $file > flagstat_out_$N.txt
done

# samtools mpileup & generate tab file for ALFRED:
for library in `ls *.dedup.bam`
do
filename_lib=$(basename $library)
lib="${filename_lib%.*}"
samtools mpileup $library | cut -f 2,4 > $lib.tsv
done


# remove dups: 
rm final_read_counts*
for library in `ls *dedup.tsv*`
do
echo "$library" >> final_read_counts_col1
cat $library | wc -l >> final_read_counts_col2
done
paste final_read_counts_col* | column -s $'\t' -t > final_read_counts
cat final_read_counts | awk '{print $1,$2,$2/4}' > final_read_counts.tsv


# get fragment sizes: 
for file in `ls *.dedup.bam`
do
filename=$(basename $file)
N="${filename%.*}"
samtools view $file | cut -f 9 > frag_sizes_$N.txt
done



