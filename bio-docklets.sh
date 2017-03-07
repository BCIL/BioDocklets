#!/bin/bash
# author: "Baekdoo Kim (baegi7942@gmail.com)"

printf "\n\t *****************************************************************************************************************\n\t ** \t Welcome to Bio-Docklets: Virtualization Containers for Single-Step Execution of NGS Data Pipelines.\t**\n\t *****************************************************************************************************************\n\n"

if [ "$(uname)" = "Darwin" ]; then
    user_os="MacOS"
elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then
    user_os="Linux"
else
	printf "** [ERROR] - This script only supports Linux or MacOS systems.\n\t Please run this script on a Linux or MacOS environment."
	exit 1
fi

if [ "$(id -u)" != "0" ]; then
	sudoer=false
	res=$(docker ps 2>&1)
	res_str=$(echo ${res::+10})
	if [ "$res_str" != "CONTAINER" ]; then
		printf "** [ERROR] - Docker does not work on your account. Please re-run this script with sudo (admin) permission.\n\n"
		exit 1
	fi
else
	sudoer=true
fi

if $sudoer && [ "$user_os" = "Linux" ]; then
	for app in 'wget' 'unzip' 'python' 'lsof'; do
		command -v $app >/dev/null 2>&1 || { echo >&2 "** Installing $app.."; apt-get install -y $app > /dev/null 2>&1; }
	done
	command -v docker >/dev/null 2>&1 || { echo >&2 "** Installing Docker.."; wget -qO- https://get.docker.com/ | sh > /dev/null 2>&1; }
	
elif $sudoer && [ "$user_os" = "MacOS" ]; then
	no_apps=false
	for app in 'wget' 'unzip' 'python' 'lsof'; do
		command -v $app >/dev/null 2>&1 || { echo >&2 "** Required $app -> NOT Installed"; no_apps=true; }
	done
	if $no_apps; then
		printf "\n[WARN] - The required application(s) above are not installed. Please re-run this script WITHOUT sudo (admin) permission.\n\tPlease make sure your Xcode version is 8.0 or higher.\n\n"
		exit 1
	fi
elif [ "$user_os" = "MacOS" ]; then
	install_allowed=false
	no_apps=false
	for app in 'wget' 'unzip' 'python' 'lsof'; do
		command -v $app >/dev/null 2>&1 || { echo >&2 "** Required $app -> NOT Installed"; no_apps=true; }
		if $no_apps && ! $install_allowed; then
			while true; do
				printf "** The required application(s) ($app) are not installed. Would you like to install them?\n   You will need to enter an administrator password. "
				read -r -p "[Y/N]: " install_app
				if [ "$install_app" = "Y" ] || [ "$install_app" = "y" ] || [ "$install_app" = "N" ] || [ "$install_app" = "n" ]; then
					break
				fi
			done
			if [ "$install_app" = "Y" ] || [ "$install_app" = "y" ]; then
				$install_allowed=true
				command -v brew >/dev/null 2>&1 || { echo >&2 "** Installing Homebrew.."; /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" > /dev/null 2>&1; }
			else
				printf "** [ERROR] - The required application(s) ($app) are not installed, and you agreed NOT to install them.\n   - Aborted.\n\n"
				exit 1
			fi
		fi
		if $no_apps && $install_allowed; then
			command -v $app >/dev/null 2>&1 || { echo >&2 "** Installing $app.."; brew install $app; }
		fi
	done
	
else
	no_apps=false
	for app in 'wget' 'unzip' 'docker' 'python' 'lsof'; do
		command -v $app >/dev/null 2>&1 || { echo >&2 "** Required $app -> NOT Installed"; no_apps=true; }
	done
	if $no_apps; then
		printf "[ERROR] - Some tools are not working on your account. Please re-run this script with sudo (admin) permission.\n\n"
		exit 1
	fi
fi

if [ "$(whoami)" = "root" ]; then
	if [ "$user_os" = "Linux" ]; then
		BCIL_data_path="/home/BCIL_pipeline_runs"
	else
		BCIL_data_path="/Users/BCIL_pipeline_runs"
	fi
else
	if [ "$user_os" = "Linux" ]; then
		BCIL_data_path="/home/$(whoami)/BCIL_pipeline_runs"
	else
		BCIL_data_path="/Users/$(whoami)/BCIL_pipeline_runs"	
	fi
fi
BCIL_data_path_input="$BCIL_data_path/input"
BCIL_data_path_output="$BCIL_data_path/output"
input_in_default_location=false

while true; do
	printf "** Default database (houses all relevant datasets (inputs, outputs, etc)) path location: '%s' \n    Would you like to set this location as the default database path? " "$BCIL_data_path"
	read -r -p "[Y/N]: " default_loc_yn
	if [ "$default_loc_yn" = "Y" ] || [ "$default_loc_yn" = "y" ] || [ "$default_loc_yn" = "N" ] || [ "$default_loc_yn" = "n" ]; then
		break
	fi
done
if [ "$default_loc_yn" = "N" ] || [ "$default_loc_yn" = "n" ]; then
	while true; do
		read -r -p "** Please provide the path to your database (houses all relevant datasets (inputs,outputs etc)) location: " new_database_loc
		if [ "$(echo -n $new_database_loc | tail -c 1)" = '/' ]; then
			new_database_loc=$(echo "${new_database_loc%?}")
		fi
		if [ ! -d $new_database_loc ]; then
			while true; do
				read -r -p "** The location to your database (houses all relevant datasets (inputs,outputs etc)) path does not exist, would you like to create one? [Y/N]: " new_database_gen_yn
				if [ "$new_database_gen_yn" = "Y" ] || [ "$new_database_gen_yn" = "y" ] || [ "$new_database_gen_yn" = "N" ] || [ "$new_database_gen_yn" = "n" ]; then
					break
				fi
			done
			if [ "$new_database_gen_yn" = "Y" ] || [ "$new_database_gen_yn" = "y" ]; then
				BCIL_data_path="$new_database_loc"
				BCIL_data_path_input="$new_database_loc/input"
				BCIL_data_path_output="$new_database_loc/output"
				echo "** Generating data folder ($BCIL_data_path)"
				res=$(mkdir -p $BCIL_data_path_input $BCIL_data_path_output 2>&1)
				if [ ! "$res" = "" ]; then
					printf "'%s'\n\n" "$res"
					continue
				else
					break
				fi
			else
				continue
			fi
		else
			### set new database path
			BCIL_data_path="$new_database_loc"
			BCIL_data_path_input="$new_database_loc/input"
			BCIL_data_path_output="$new_database_loc/output"
			break
		fi
	done

else
	if [ ! -d $BCIL_data_path ]; then
		echo "** Generating data folder ($BCIL_data_path)" 
		mkdir -p $BCIL_data_path $BCIL_data_path_input $BCIL_data_path_output 
	fi
fi

printf "** Working PATH: '%s'\n\n" "$BCIL_data_path"
printf "*************************************\n* 1. ChIP-Seq - Single-End \n* 2. ChIP-Seq - Paired-End \n* 3. RNA-Seq - Tophat_2 (Bowtie_2) \n*************************************\n"
while true; do
	read -r -p "* Select [1-3]: " pipeline_option
	if [ "$pipeline_option" = "1" ] || [ "$pipeline_option" = "2" ] || [ "$pipeline_option" = "3" ]; then
		break
	fi
done
printf "*************************************\n\n"

if [ "$pipeline_option" = "1" ]; then
	pipeline_name="ChIPsequser_latest"
elif [ "$pipeline_option" = "2" ]; then
	pipeline_name="ChIPsequser_paired_latest"
elif [ "$pipeline_option" = "3" ];then
	pipeline_name="RNAsequser_tophat2_latest"
else
	echo "** ERROR - Something went wrong while trying to retreive the pipeline!! Please rerun this script from the start."
	exit 1
fi

if [ "$pipeline_option" = "1" ] || [ "$pipeline_option" = "2" ]; then
	printf "\t** ChIP-Seq **\n"
	input_data_should_be_in="$BCIL_data_path_input/CHIPseq"
	mkdir -p $input_data_should_be_in
	while true; do
		if [ "$pipeline_option" = "1" ]; then
			printf "* Please provide the directory path of your ONE Single-End fastq file for the ChIP-Seq pipeline (Single-End). OR\n  Just hit the enter button if your input data is already located in '%s'.\n" "$input_data_should_be_in"
		elif [ "$pipeline_option" = "2" ]; then
			printf "* Please provide the directory path of your TWO Paired-End fastq files for ChIP-Seq pipeline (Paired-End). OR\n  Just hit the enter button if your input data already located in '%s'.\n" "$input_data_should_be_in"
		fi
		read -r -p "> " ChIPSeq_user_input_path

		if [ "$(echo -n $ChIPSeq_user_input_path | tail -c 1)" = '/' ]; then
			ChIPSeq_user_input_path=$(echo "${ChIPSeq_user_input_path%?}")
		fi
		if [ ! "$ChIPSeq_user_input_path" = "" ]; then
			isEmpty=$(find "$ChIPSeq_user_input_path" -maxdepth 0 -empty -exec echo "true" \;)
			if [ ! -d $ChIPSeq_user_input_path ]; then
				printf "== The location of your input folder ($ChIPSeq_user_input_path) does not exist!\n\n"
				continue
			elif [ "$isEmpty" = "true" ]; then
				printf "== Your input folder is empty!\n\n"
				continue
			else
				c="$(ls -l $ChIPSeq_user_input_path | grep '.fastq' |  wc -l)"
				if ([ "$pipeline_option" = "1" ] && [ "$(echo $c)" = "1" ]) || ([ "$pipeline_option" = "2" ] && [ "$(echo $c)" = "2" ]); then
					ChIPSeq_input_path="$ChIPSeq_user_input_path"
					allow_to_autorun_pipelines="true"
					break
				else
					printf "[WARNING] - $pipeline_name only requires $pipeline_option fastq file, but your input folder contains $c fastq file(s). The pipeline may not recieve the correct input data.\n"
					while true; do
						read -r -p "* CONTINUE? [Y/N]" input_num_warn_msg
						if [ "$input_num_warn_msg" = "Y" ] || [ "$input_num_warn_msg" = "y" ] || [ "$input_num_warn_msg" = "N" ] || [ "$input_num_warn_msg" = "n" ]; then
						break
						fi
					done
					if [ "$input_num_warn_msg" = "Y" ] || [ "$input_num_warn_msg" = "y" ]; then
						ChIPSeq_input_path="$ChIPSeq_user_input_path"
						allow_to_autorun_pipelines="true"
						break
					else
						continue
					fi
				fi
			fi
		else
			while true; do
				read -r -p "* Your input data ($pipeline_option of fastq file(s)) is already placed in '$BCIL_data_path_input/CHIPseq'? [Y/N]: " input_data_prelocated_yn
				if [ "$input_data_prelocated_yn" = "Y" ] || [ "$input_data_prelocated_yn" = "y" ] || [ "$input_data_prelocated_yn" = "N" ] || [ "$input_data_prelocated_yn" = "n" ]; then
					break
				fi
			done
			if [ "$input_data_prelocated_yn" = "Y" ] || [ "$input_data_prelocated_yn" = "y" ]; then
				if [ ! -d $BCIL_data_path_input/CHIPseq ]; then
					printf "== Your input path ($BCIL_data_path_input/CHIPseq) does not exist!\n\n"
					continue
				else
					c="$(ls -l $input_data_should_be_in | grep '.fastq' |  wc -l)"
					if ([ "$pipeline_option" = "1" ] && [ "$(echo $c)" = "1" ]) || ([ "$pipeline_option" = "2" ] && [ "$(echo $c)" = "2" ]); then
						ChIPSeq_input_path="$BCIL_data_path_input/CHIPseq"
						input_in_default_location=true
						allow_to_autorun_pipelines="true"
						break
					else
						printf "[WARNING] - $pipeline_name only requires $pipeline_option fastq file, but your input folder contains $c fastq file(s). The pipeline may not recieve the correct input data.\n"
						while true; do
							read -r -p "* CONTINUE? [Y/N]" input_num_warn_msg
							if [ "$input_num_warn_msg" = "Y" ] || [ "$input_num_warn_msg" = "y" ] || [ "$input_num_warn_msg" = "N" ] || [ "$input_num_warn_msg" = "n" ]; then
							break
							fi
						done
						if [ "$input_num_warn_msg" = "Y" ] || [ "$input_num_warn_msg" = "y" ]; then
							ChIPSeq_input_path="$BCIL_data_path_input/CHIPseq"
							input_in_default_location=true
							allow_to_autorun_pipelines="true"
							break
						else
							continue
						fi
					fi

				fi
			else
				while true; do
					read -r -p "* Would you like to provide the location path of your input dataset(s)? Enter - [Y/N] : " move_to_type_input_path
					if [ "$move_to_type_input_path" = "Y" ] || [ "$move_to_type_input_path" = "y" ] || [ "$move_to_type_input_path" = "N" ] || [ "$move_to_type_input_path" = "n" ]; then
						break
					fi
				done
				if [ "$move_to_type_input_path" = "Y" ] || [ "$move_to_type_input_path" = "y" ]; then
					continue
				else
					echo "* ------------------------------------------------------------------------------------"
					echo "* Please make sure your input data is placed in $BCIL_data_path_input/CHIPseq. "
					#echo "* Auto pipeline run - Disabled. "
					echo "* ------------------------------------------------------------------------------------"
					allow_to_autorun_pipelines="false"
					break
				fi
			fi
		fi
		d=$(ls $ChIPSeq_input_path)
		input_path_detail=()
		fastqFile_num=0
		for i in $d; do
			input_path_detail+=('$i')
			chk_fq=$(echo ${i: -2})
			chk_fastq=$(echo ${i: -5})
			if [ "$chk_fq" = "fq" ] || [ "$chk_fastq" = "fastq" ]; then  # *.fq || *.fastq
				fastqFile_num=$((fastqFile_num+1))
			fi
		done
		if [ "$allow_to_autorun_pipelines" = "true" ]; then
			if [ "$fastqFile_num" = "0" ]; then
				printf "== Warning! The provided path (%s) does not contain fastq file(s).\n$pipeline_name pipeline required $pipeline_option FASTQ format file(s) (*.fastq). Below are more detail(s) of the folder path:\n" "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "  "
				ls "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "\n"
				continue
			elif [ "$pipeline_option" = "1" ] && [ "$fastqFile_num" -gt "1" ]; then
				printf "== Warning! The provided path (%s) contains multiple fastq files. $pipeline_name pipeline requires only ONE fastq file.\n== Please make sure to place only one fastq file inside the folder. Below is more detail(s) of the location of the folder:\n" "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "  "
				ls "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "\n"
				continue
			elif [ "$pipeline_option" = "2" ] && [ "$fastqFile_num" -lt "2" ] || [ "$fastqFile_num" -gt "2" ]; then
				printf "== Warning! The provided path (%s) contains multiple fastq files. $pipeline_name pipeline requires only TWO fastq files.\n== Please make sure to place only TWO fastq files inside the folder. Below is more detail(s) of the location of the folder: \n" "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "  "
				ls "$ChIPSeq_input_path"
				echo "-----------------------------------------------------------------------------------------------------------"
				printf "\n"
				if [ ! "$input_num_warn_msg" = "Y" ] || [ ! "$input_num_warn_msg" = "y" ]; then
					continue
				fi
			fi				
		fi
		break	
	done

	printf "\n***** Please provide the values for the following tool parameters of the Bowtie2 and MACS2 tools *****\n"
	while true; do
		printf "* Please enter an Insert Size (default: 200):"
		read -r -p ": " insert_size
		if [ "$insert_size" = "" ]; then
			insert_size=200
			echo "[INFO] - Set default value ($insert_size)"
			break
		elif [[ $insert_size =~ [0-9]+$ ]]; then break; else continue; fi
	done
	while true; do
		printf "* Please provide a P-Value cutoff (default: 0.01):"
		read -r -p ": " pvalue
		if [ "$pvalue" = "" ]; then
			pvalue=0.01
			echo "[INFO] - Set default value ($pvalue)"
			break
		elif [[ $pvalue < 1 ]]; then break; else continue; fi
	done
	while true; do
		printf "* Please enter the genome size of your organism of study (default: 2700000000):"
		read -r -p ": " gsize
		if [ "$gsize" = "" ]; then
			gsize=2700000000
			echo "[INFO] - Set default value ($gsize)"
			break
		fi
		if [[ $gsize =~ [0-9]+$ ]]; then break; else continue; fi
	done
fi

if [ "$pipeline_option" = "3" ]; then
	printf "\t** RNA-Seq **\n"
	input_data_should_be_in="$BCIL_data_path_input/RNAseq"
	mkdir -p $input_data_should_be_in
	while true; do
		printf "* Please provide the location (entire path) of your RNA-Seq paired-end files and annotation file, '*.gtf'.\n  The total number of required input files should be 5. \n  If the input data is already located in '%s' then please hit enter. If not, you will need to copy or move your data inside the following folder path ('%s'). \n" "$BCIL_data_path_input/RNAseq" "$BCIL_data_path_input/RNAseq"
		read -r -p "> " RNAseq_input_path
		if [ "$(echo -n $RNAseq_input_path | tail -c 1)" = '/' ]; then
			RNAseq_input_path=$(echo "${RNAseq_input_path%?}")
		fi
		if [ ! "$RNAseq_input_path" = "" ]; then
			allow_to_autorun_pipelines="true"
			isEmpty=$(find "$RNAseq_input_path" -maxdepth 0 -empty -exec echo "true" \;)
			if [ ! -d $RNAseq_input_path ]; then
				printf "== The location of your input folder  ($RNAseq_input_path) does not exist!\n\n"
				continue
			elif [ "$isEmpty" = "true" ]; then
				printf "== Your input folder is empty!\n\n"
				continue
			fi
		else
			while true; do
				read -r -p "* Is your input data already placed in '$BCIL_data_path_input/RNAseq'? [Y/N]: " input_data_prelocated_yn
				if [ "$input_data_prelocated_yn" = "Y" ] || [ "$input_data_prelocated_yn" = "y" ] || [ "$input_data_prelocated_yn" = "N" ] || [ "$input_data_prelocated_yn" = "n" ]; then
					break
				fi
			done
			if [ "$input_data_prelocated_yn" = "Y" ] || [ "$input_data_prelocated_yn" = "y" ]; then
				if [ ! -d $BCIL_data_path_input/RNAseq ]; then
					printf "== The location of your input folder ('%s') does not exist!\n\n" "$BCIL_data_path_input/RNAseq"
					continue
				else
					allow_to_autorun_pipelines="true"
					input_in_default_location=true
					RNAseq_input_path="$BCIL_data_path_input/RNAseq"	
				fi		
			else
				while true; do
					read -r -p "* Would you like to provide the location of your input data? [Y/N]: " move_to_type_input_path
					if [ "$move_to_type_input_path" = "Y" ] || [ "$move_to_type_input_path" = "y" ] || [ "$move_to_type_input_path" = "N" ] || [ "$move_to_type_input_path" = "n" ]; then
						break
					fi
				done
				if [ "$move_to_type_input_path" = "Y" ] || [ "$move_to_type_input_path" = "y" ]; then
					continue
				else
					echo "* ------------------------------------------------------------------------------------"
					echo "* Please make sure your input data is placed in $BCIL_data_path_input/RNAseq. "
					#echo "* Auto pipeline run - Disabled. "
					echo "* ------------------------------------------------------------------------------------"
					allow_to_autorun_pipelines="false"
					break
				fi
			fi	
		fi
		d=$(ls $RNAseq_input_path)
		input_path_detail=()
		fastqFile_num=0
		gtfFile_num=0
		for i in $d; do
			input_path_detail+=('$i')
			chk_fq=$(echo ${i: -2})
			chk_fastq=$(echo ${i: -5})
			chk_gtf=$(echo ${i: -3})
			if [ "$chk_fq" = "fq" ] || [ "$chk_fastq" = "fastq" ]; then  # *.fq || *.fastq
				fastqFile_num=$((fastqFile_num+1))
			elif [ "$chk_gtf" = "gtf" ]; then
				gtfFile_num=$((gtfFile_num+1))
			fi
		done
		if [ "$fastqFile_num" = "0" ]; then
			printf "== Warning! The provided path (%s) does not contain fastq file(s).\nThe RNA-Seq pipeline requires four FASTQ format file(s) (*.fastq) and one GTF file (*.gtf). Below is more detail(s) of the path:\n" "$RNAseq_input_path"
			echo "-----------------------------------------------------------------------------------------------------------"
			printf "  "
			ls "$RNAseq_input_path"
			echo "-----------------------------------------------------------------------------------------------------------"
			printf "\n"
			continue
		elif [ "$fastqFile_num" != "4" ]; then
			printf "== Warning! The number of fastq file(s) does not match the number of expected input file(s).\n\tRNA-Seq pipeline requires FOUR fastq files and ONE gtf file.\n== Please make sure to place the correct number of input data inside the folder. Below is more detail(s) of the path.\n" "$RNAseq_input_path"
			echo "-----------------------------------------------------------------------------------------------------------"
			printf "  "
			ls "$RNAseq_input_path"
			echo "-----------------------------------------------------------------------------------------------------------"
			printf "\n"
			continue
		elif [ "$gtfFile_num" = "0" ]; then
			while true; do
				echo "-----------------------------------------------------------------------------------------------------------"
				read -r -p "== Warning! Your input folder does not contain a gene annotation file (*.gtf). Would you like to download the hg38 annotation file from our Bundle Resource? [Y/N]: " download_gtf_yn
				if [ "$download_gtf_yn" = "Y" ] || [ "$download_gtf_yn" = "y" ] || [ "$download_gtf_yn" = "N" ] || [ "$download_gtf_yn" = "n" ]; then
					break
				fi
			done
			if [ "$download_gtf_yn" = "N" ] || [ "$download_gtf_yn" = "n" ]; then
				echo "-----------------------------------------------------------------------------------------------------------"
				continue
			fi
		fi
		break
	done
	printf "\n***** Please provide values for the following tool paramerters of the Tophat2 tool *****\n"
	while true; do
		printf "* Please enter a value for the Insert Size (default: 20)"
		read -r -p ": " insert_size
		if [ "$insert_size" = "" ]; then
			insert_size=20
			echo "[INFO] - Set default value ($insert_size)"
			break
		elif [[ $insert_size =~ [0-9]+$ ]]; then break; else continue; fi
	done
	while true; do
		printf "* Please enter a value for the Anchor_length (default: 8)"
		read -r -p ": " anchor_length
		if [ "$anchor_length" = "" ]; then
			anchor_length=8
			echo "[INFO] - Set default value ($anchor_length)"
			break
		elif [[ $anchor_length =~ [0-9]+$ ]]; then break; else continue; fi
	done
	while true; do
		printf "* Please enter a value for the minimum length of read segments (default: 25)"
		read -r -p ": " segment_length
		if [ "$segment_length" = "" ]; then
			segment_length=25
			echo "[INFO] - Set default value ($segment_length)"
			break
		elif [[ $segment_length =~ [0-9]+$ ]]; then break; else continue; fi
	done
fi

if ! $input_in_default_location; then
	#if ! $sudoer; then
		while true; do
			printf "\n== A data directory will be generated to house all the required data (input, outputs etc). Your input data will be relocated there, would you like to copy(SLOW) or move(FAST) your input data from its current location?\n"
			read -r -p "== Please type 'Y'(copy) or 'N'(move): " cp_or_mv
			if [ "$cp_or_mv" = "Y" ] || [ "$cp_or_mv" = "y" ] || [ "$cp_or_mv" = "N" ] || [ "$cp_or_mv" = "n" ]; then
				break
			fi
		done
	#fi
fi

printf "\n-------------------------------------------------------------------------------------------\n"
while true; do
	printf "* Is your analysis on the human organism? \n   If yes, we have pre-built references that can be used to run the analysis. \n   If not, please provide the location path of the reference genome of your organism of study. \n "
	read -r -p " Type [Y/N]: " ref_yn
	if [ "$ref_yn" = "Y" ] || [ "$ref_yn" = "y" ] || [ "$ref_yn" = "N" ] || [ "$ref_yn" = "n" ]; then	
		break
	fi
done

#Deprecated pipeline using bowtie 1.
bowtie_ver="2"

if [ "$ref_yn" = "Y" ] || [ "$ref_yn" = "y" ]; then
	while true; do
		printf "\n* Would you like to download the human reference genome (hg38) and pre-built bowtie indices from our Bundle Resource? "
		read -r -p "[Y/N]: " use_built_in_ref_yn
		if [ "$use_built_in_ref_yn" = "Y" ] || [ "$use_built_in_ref_yn" = "y" ] || [ "$use_built_in_ref_yn" = "N" ] || [ "$use_built_in_ref_yn" = "n" ]; then	
			break
		fi
	done
else
	use_built_in_ref_yn="N"
fi

printf "\n-------------------------------------------------------------------------------------------\n"
if [ "$use_built_in_ref_yn" = "N" ] || [ "$use_built_in_ref_yn" = "n" ]; then
	printf "\n-- You can compile new bowtie indices of your reference genome or to save time provide the path of your pre-built indices --\n"
	while true; do
		read -r -p "* Do you have pre-built indices of your reference genome? [Y/N]: " user_indices_yn
		if [ "$user_indices_yn" = "Y" ] || [ "$user_indices_yn" = "y" ] || [ "$user_indices_yn" = "N" ] || [ "$user_indices_yn" = "n" ];then
			break
		fi
	done
	if [ "$user_indices_yn" = "Y" ] || [ "$user_indices_yn" = "y" ]; then
		while true; do
			read -r -p "* Please provide the location path of your pre-built Bowtie2 indices: " ref_path_user	
				if [ "$(echo -n $ref_path_user | tail -c 1)" = '/' ]; then
					ref_path_user=$(echo "${ref_path_user%?}")
				fi
			if [ ! -d $ref_path_user ]; then
				echo "** [ERROR] - Your input path ($ref_path_user) does not exist!"
				continue
			else
				if [ "$(ls $ref_path_user | grep -E '\^*\.bt2' | wc -l)" = "0" ]; then
					echo "** [ERROR] - Cannot find Bowtie 2 index files!"
					continue
				elif [ "$(ls $ref_path_user | grep -E '\^*\.bt2' | wc -l)" -lt "6" ]; then
					echo "** [ERROR] - The path contains invalid number of Bowtie 2 index files! ( 6 files required )"
					continue
				else
					break
				fi 
			fi
		done
	else
		while true; do
			printf "\n-------------------------------------------------------------------------------------------\n"
			printf "* Compiling new indices will take several hours. \n* Do you want to continue? "
			read -r -p "[Continue(Y) / Abort(N)]: " bowtie_warn
			printf "\n-------------------------------------------------------------------------------------------\n"
			if [ "$bowtie_warn" = "Y" ] || [ "$bowtie_warn" = "y" ] || [ "$bowtie_warn" = "N" ] || [ "$bowtie_warn" = "n" ]; then	
				break
			fi
			echo ""
		done
		if [ "$bowtie_warn" = "Y" ] || [ "$bowtie_warn" = "y" ]; then
			if [ "$pipeline_option" = "2" ]; then
				bowtie_ver="1"
				echo "* Bowtie1 indices will be generated."
			else 
				bowtie_ver="2"
				echo "* Bowtie2 indices will be generated."
			fi
			while true; do
				printf "* Please provide the location path of your reference genome (fasta) that includes the file name: \n* e.g. /reference/file/path/genomefilename.fa \n"
				read -r -p " > " ref_path_user
				# if [ "$(echo -n $ref_path_user | tail -c 1)" = '/' ]; then
				# 	ref_path_user=$(echo "${ref_path_user%?}")
				# fi
				# if [ ! -d $ref_path_user ]; then
				# 	echo "** [ERROR] - Your reference genome file does not exist! ($ref_path_user)"
				# 	continue
				if ! [ -f $ref_path_user ]; then
					printf "\n** [ERROR] - Your reference genome file does not exist! ($ref_path_user)\n\n"
					continue
				else
					break
				fi
			done
		else
			printf "\n\t Aborted. \n\n"
			exit 1
		fi
	fi
fi
if [ "$allow_to_autorun_pipelines" = "true" ]; then
	while true; do
		printf "\n"
		read -r -p "* Would you like to run the pipeline automatically right after this setup? (Y/N): " auto_launch_pipeline
		if [ "$auto_launch_pipeline" = "Y" ] || [ "$auto_launch_pipeline" = "y" ] || [ "$auto_launch_pipeline" = "N" ] || [ "$auto_launch_pipeline" = "n" ]; then
			break
		fi
	done
	if [ "$auto_launch_pipeline" = "Y" ] || [ "$auto_launch_pipeline" = "y" ]; then
		auto_launch_pipeline="Y"
	else
		auto_launch_pipeline="N"
	fi
else
	auto_launch_pipeline="N"
fi

#printf "\n************ Please ignore this part ************\n"
hn=$(curl --max-time 1 http://169.254.169.254/latest/meta-data/public-hostname > /dev/null 2>&1)
#printf "\n*************************************************\n"
user_ip=""
pipeline_port=9001
is_AWS="false"
if [ "$hn" != "" ]; then
	IFS='-' read -ra arr <<< "$hn"
	hn_ip=${arr[0]}
	for i in 1 2 3 4; do 
		if [ "$i" == 4 ]; then
			IFS='.' read -ra tmp <<< "${arr[$i]}"
			user_ip+=${tmp[0]}
		else
			user_ip+=${arr[$i]}
		fi
		
		if [ "$i" != 4 ]; then
			user_ip+='.'
		fi 
	done
	is_AWS="true"
else
	user_ip=$(wget http://ipinfo.io/ip -qO -)
	if [ "$user_ip" = "" ]; then
		user_ip="127.0.0.1"
	fi
fi
if ($sudoer && [ "$user_os" = "Linux" ]) || [ "$user_os" = "MacOS" ]; then
	while true; do
		if lsof -Pi :$pipeline_port -sTCP:LISTEN -t > /dev/null ; then 
			pipeline_port=$((pipeline_port+1))
		else
			break
		fi
	done
else
	pipeline_port="9877"
fi
printf "** Galaxy server address: %s:%s ** \n\n" "$user_ip" "$pipeline_port"

echo "*******************************************************************************************"
echo " "

if [ "$allow_to_autorun_pipelines" = "true" ]; then
	DATE=`date +%Y-%m-%d:%H:%M:%S`
	if [ "$pipeline_option" = "1" ] || [ "$pipeline_option" = "2" ]; then
		echo "** Initializing ChIP-Seq input..."
		BCIL_input_data_mount_path="$BCIL_data_path_input/CHIPseq"
		if ! $input_in_default_location; then
			if [ ! "$ChIPSeq_input_path" = "$BCIL_input_data_mount_path" ]; then
				#if $sudoer; then
				#	cmd="mount -o bind"
				if [ "$cp_or_mv" = "Y" ] || [ "$cp_or_mv" = "y" ]; then
					cmd="cp -r -T"
				else
					cmd="mv"
				fi
				dest=$BCIL_input_data_mount_path"_old_"$DATE
				if [ -d $BCIL_input_data_mount_path ] && [ ! "$(ls $BCIL_input_data_mount_path)" = "" ]; then 
					mv $BCIL_input_data_mount_path $dest
					mkdir -p $BCIL_input_data_mount_path
				elif [ ! -d $BCIL_input_data_mount_path ]; then
					mkdir -p $BCIL_input_data_mount_path
				else
					printf '\n'
				fi
				$cmd $ChIPSeq_input_path $BCIL_input_data_mount_path
			fi
		fi
	elif [ "$pipeline_option" = "3" ]; then
		echo "** Initializing RNA-Seq input..."
		BCIL_input_data_mount_path="$BCIL_data_path_input/RNAseq"
		if [ "$download_gtf_yn" = "Y" ] || [ "$download_gtf_yn" = "y" ]; then
			wget -r -R index.html -N -nd -np http://146.95.173.35:9988/hg38/Annotation/genes.gtf -P "$RNAseq_input_path" --progress=bar:force 2>&1 | tail -f -n +6
		fi
		if ! $input_in_default_location; then
			if [ ! "$RNAseq_input_path" = "$BCIL_input_data_mount_path" ]; then
				#if $sudoer; then
				#	cmd="mount -o bind"
				if [ "$cp_or_mv" = "Y" ] || [ "$cp_or_mv" = "y" ]; then
					cmd="cp -r -T"
				else
					cmd="mv"
				fi
				dest=$BCIL_input_data_mount_path"_old_"$DATE
				if [ -d $BCIL_input_data_mount_path ] && [ ! "$(ls $BCIL_input_data_mount_path)" = "" ]; then 
					mv $BCIL_input_data_mount_path $dest
					mkdir -p $BCIL_input_data_mount_path
				elif [ ! -d $BCIL_input_data_mount_path ]; then
					mkdir -p $BCIL_input_data_mount_path
				else
					printf '\n'
				fi
				$cmd $RNAseq_input_path $BCIL_input_data_mount_path
			fi
		fi
	fi
else
	if [ "$pipeline_option" = "1" ] || [ "$pipeline_option" = "2" ]; then
		pipeline_input_path="$BCIL_data_path_input/CHIPseq/"
	elif [ "$pipeline_option" = "3" ]; then
		pipeline_input_path="$BCIL_data_path_input/RNAseq/"
	fi
	printf "\n*******************************************************\n*\t\t - [INFO] - \n* You did not provide the location of your input folder. \n* Please copy or move your input data to the following location %s \n*******************************************************\n\n" "$pipeline_input_path"
fi


if [ "$use_built_in_ref_yn" = "Y" ] || [ "$use_built_in_ref_yn" = "y" ];then
	echo "** Downloading Bowtie indices of human organism(hg38) from BCIL bundle resource..."
	if [ "$bowtie_ver" = "1" ]; then
		mkdir -p "$BCIL_data_path_input/hg38bt1"
		wget -r -R index.html -N -nd -np http://146.95.173.35:9988/hg38/Sequence/Bowtie_1/ -P "$BCIL_data_path_input/hg38bt1" --progress=bar:force 2>&1 | tail -f -n +6
	elif [ "$bowtie_ver" = "2" ]; then
		mkdir -p "$BCIL_data_path_input/hg38"
		wget -r -R index.html -N -nd -np http://146.95.173.35:9988/hg38/Sequence/Bowtie_2/ -P "$BCIL_data_path_input/hg38" --progress=bar:force 2>&1 | tail -f -n +6
	fi
else	# user own reference
	DATE=`date +%Y-%m-%d:%H:%M:%S`
	if [ "$user_indices_yn" = "Y" ] || [ "$user_indices_yn" = "y" ]; then
		echo "** Copying your reference files..."
		
		if [ "$(echo -n $ref_path_user | tail -c 1)" = '/' ]; then
			ref_path_user=$(echo "${ref_path_user%?}")
		fi
		if [ "$bowtie_ver" = "1" ]; then
			if [ -d "$BCIL_data_path_input/hg38bt1" ]; then
				dest=$BCIL_data_path_input/hg38bt1"_old_"$DATE
				mv $BCIL_data_path_input/hg38bt1 $dest
				mkdir -p $BCIL_data_path_input/hg38bt1
			fi
			cp -r "$ref_path_user" "$BCIL_data_path_input/hg38bt1"
			for f in $(ls $BCIL_data_path_input/hg38bt1); do mv $BCIL_data_path_input/hg38bt1/$f $BCIL_data_path_input/hg38bt1/$(echo $f | sed s/"${f/.*}"/hg38/); done
		elif [ "$bowtie_ver" = "2" ]; then
			if [ -d "$BCIL_data_path_input/hg38" ] && [ ! "$(ls $BCIL_data_path_input/hg38)" = "" ]; then
				if [ ! "$ref_path_user" = "$BCIL_data_path_input/hg38" ]; then
					dest=$BCIL_data_path_input/hg38"_old_"$DATE
					mv $BCIL_data_path_input/hg38 $dest
					mkdir -p $BCIL_data_path_input/hg38
				fi
			fi
			if [ ! "$ref_path_user" = "$BCIL_data_path_input/hg38" ]; then
				cp -r "$ref_path_user" "$BCIL_data_path_input/hg38"
				for f in $(ls $BCIL_data_path_input/hg38); do mv $BCIL_data_path_input/hg38/$f $BCIL_data_path_input/hg38/$(echo $f | sed s/"${f/.*}"/hg38/); done
			fi
		fi
	elif [ "$user_indices_yn" = "N" ] || [ "$user_indices_yn" = "n" ]; then
		printf "** Installing Bowtie_$bowtie_ver...\n"
		if [ "$bowtie_ver" = "1" ]; then
			if [ "$(which bowtie)" = '' ]; then
				if [ "$(ls /home/bowtie)" = '' ]; then
					mkdir -p /home/bowtie
					wget -N -O /home/bowtie/bowtie-1.1.2-linux-x86_64.zip https://sourceforge.net/projects/bowtie-bio/files/bowtie/1.1.2/bowtie-1.1.2-linux-x86_64.zip/download --progress=bar:force 2>&1 | tail -f -n +6
					unzip -j /home/bowtie/\*.zip -d /home/bowtie 
				fi
			fi
		elif [ "$bowtie_ver" = "2" ]; then
			if [ "$(which bowtie2)" = '' ]; then
				if [ "$(ls /home/bowtie2)" = '' ]; then
					mkdir -p /home/bowtie2
					wget -N -O /home/bowtie2/bowtie2-2.2.7-linux-x86_64.zip https://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.2.7/bowtie2-2.2.7-linux-x86_64.zip/download --progress=bar:force 2>&1 | tail -f -n +6
					unzip -j /home/bowtie2/\*.zip -d /home/bowtie2
				fi
			fi 
		fi

		printf "\n**********************************************************************\n** Building Bowtie$bowtie_ver indices..\n** This job will take several hours (depending on system performance).\n**********************************************************************\n"
		ref_fname=${ref_path_user##*/}
		#bowtie_prefix=${ref_fname%.*}
		bowtie_prefix="hg38"  # This is a preset value inside the Galaxy.
		bowtie_1_path="$BCIL_data_path_input/hg38bt1"
		bowtie_2_path="$BCIL_data_path_input/hg38"

		if [ "$bowtie_ver" = "1" ]; then
			mkdir -p $bowtie_1_path
			cp $ref_path_user $bowtie_1_path
			ref_file_path=$(echo $bowtie_1_path/$ref_fname)
			cd "$bowtie_1_path" && /home/bowtie/bowtie-build $ref_file_path $bowtie_prefix
		else
			mkdir -p $bowtie_2_path
			cp $ref_path_user $bowtie_2_path
			ref_file_path=$(echo $bowtie_2_path/$ref_fname)
			cd "$bowtie_2_path" && /home/bowtie2/bowtie2-build $ref_file_path $bowtie_prefix
		fi
	fi
fi

if [ "$pipeline_option" = "1" ]; then
	pipeline_name="ChIPsequser_latest"
	repo_pipeline="bcil/pipelines:$pipeline_name"
elif [ "$pipeline_option" = "2" ]; then
	pipeline_name="ChIPsequser_paired_latest"
	repo_pipeline="bcil/pipelines:$pipeline_name"
elif [ "$pipeline_option" = "3" ]; then
	pipeline_name="RNAsequser_tophat2_latest"
	repo_pipeline="bcil/pipelines:$pipeline_name"
else
	echo "** [ERROR] - Something went wrong while trying to retreive the pipeline!!"
	exit 1
fi

printf "\n** Downloading launch-pipelines script..\n\n"
rm $BCIL_data_path/launch-pipelines.py > /dev/null 2>&1
wget -O $BCIL_data_path/launch-pipelines.py https://www.dropbox.com/s/bykxqu867jy263w/launch-pipeline.py?dl=0 --progress=bar:force 2>&1 | tail -f -n +6 > /dev/null 2>&1

printf "** Preparing the pipeline... - $repo_pipeline\n"
docker pull $repo_pipeline

if [ "$auto_launch_pipeline" = "Y" ] || [ "$auto_launch_pipeline" = "y" ]; then
	printf "\n\t** Starting launch-pipelines script... ** \n\n"
	if [ "$is_AWS" = "true" ]; then
		printf "\n**********************************************************************************\n"
		printf "** AWS elastic IP address to connect Galaxy server: %s:%s ** \n" "$user_ip" "$pipeline_port"
		printf "**********************************************************************************\n"
	else
		if [ "$user_ip" != '' ]; then
			printf "\n*********************************************************\n"
			printf "** Galaxy server address: %s:%s ** \n" "$user_ip" "$pipeline_port"
			printf "*********************************************************\n"
		fi
	fi
	if [ "$pipeline_option" = "1" ] || [ "$pipeline_option" = "2" ]; then
		printf "** Running ChIP-Seq pipeline **\n"
		python $BCIL_data_path/launch-pipelines.py $BCIL_data_path $pipeline_name $pipeline_port $insert_size $pvalue $gsize
	elif [ "$pipeline_option" = "3" ]; then
		printf "** Running RNA-Seq pipeline **\n"
		python $BCIL_data_path/launch-pipelines.py $BCIL_data_path $pipeline_name $pipeline_port $insert_size $anchor_length $segment_length
	else
		python $BCIL_data_path/launch-pipelines.py $BCIL_data_path $pipeline_name $pipeline_port
	fi
	echo ""
	if $sudoer; then
		umount "$BCIL_input_data_mount_path" > /dev/null 2>&1
	fi
	exit 0 
else
	printf "\n* You are ready to run Bio-Docklets: %s\n" "$pipeline_name"
	echo "  ------------------------------------------- Warning! Please Do Not Forget.. ----------------------------------------"
	echo "  - Please make sure your input data is placed in $input_data_should_be_in before running the $pipeline_name. "
	echo "  --------------------------------------------------------------------------------------------------------------------"
	printf "* Type this command to run the pipeline: 'python %s/launch-pipelines.py %s %s %s'\n" "$BCIL_data_path" "$BCIL_data_path" "$pipeline_name" "$pipeline_port"
	printf "* Your input data should be placed in: %s\n" "$input_data_should_be_in"
	printf "* Done.\n"
	exit 0
fi