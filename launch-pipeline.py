#!/usr/bin/python
__author__ = "Baekdoo Kim (baegi7942@gmail.com)"

import subprocess
from subprocess import check_output
import socket
import fcntl
import struct
import sys
import time
import datetime
import shlex
import string
import random
import os

########################################################
#
#	Please run 'bio-docklets.sh' instead of this script.
#
#	This script only runs as a bridge script for BioDocklets
#
#
#######################   ARGVs  #######################
#
#   [common ARGVs 1-3] [specified ARGVs 4-*]
#                               1. data_path
#                               2. pipeline_name
#                               3. pipeline_port
#------------------------------------------------
#           ChIP-Seq            4. Insert_size
#                               5. pvalue
#                               6. gsize
#                               7. bwidth
#------------------------------------------------
#           RNA-Seq             4. mate_std_dev
#                               5. anchor_length
#                               6. segment_length
#------------------------------------------------


def validate_run():
    if len(sys.argv) < 6:
	sys.exit("*** Please execute 'bio-docklets.sh' instead of this script. ***")

def get_ip_address(ifname):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("google.com", 80))
        user_ip = s.getsockname()[0]
        s.close()
    except:
        user_ip = '127.0.0.1'
    finally:
        print "**************************************************"
        print " - IP Address: %s" % (user_ip)
        return user_ip


def get_image():
    ChIPsequser = "ChIPseq_single"
    ChIPsequser_paired = "ChIPseq_paired"
    RNAsequser_tophat1 = "RNAsequser_tophat1_latest"
    RNAsequser_tophat2 = "RNAseq_paired"
    GATK_v37 = "GATKuser1_latest"
    GATK_hg19 = "GATKuser2_latest"
    miRNAseq = "miRNAseq_latest"
    QC = "QC_latest"
    BAM_QC = "BAM_QC_latest"

    def show_help():
        print "\n  --------------- Please select a pipline ---------------"
        print "  1. ChIP-Seq\n  2. RNA-Seq - tophat 1 (Bowtie_1)\n  3. RNA-Seq - tophat 2 (Bowtie_2)\n  4. GATK - b37\n  5. GATK - hg19\n  6. miRNA-Seq\n  7. FastQC\n  8. BAM-QC\n  0. Type one BCIL pipeline name"
        print "  -------------------------------------------------------"
    if len(sys.argv) > 2:
        pipeline_name = sys.argv[2]
        print " - Pipeline: %s" % sys.argv[2]
        return pipeline_name
    else:
        while(True):
            show_help()
            i = raw_input(" - Enter a number of the options above: ")
            if i is not "":
                if i in '1':
                    i = ChIPsequser
                    return i
                elif i in '2':
                    i = RNAsequser_tophat1
                    return i
                elif i in '3':
                    i = RNAsequser_tophat2
                    return i
                elif i in '4':
                    i = GATK_v37
                    return i
                elif i in '5':
                    i = GATK_hg19
                    return i
                elif i in '6':
                    i = miRNAseq
                    return i
                elif i in '7':
                    i = QC
                    return i
                elif i in '8':
                    i = BAM_QC
                    return i
                elif i in '0':
                    i = raw_input(
                        " - Type your pipeline name (e.g. user/image:tag): ")
                    return i
                else:
                    show_help()
                    i = raw_input(" - Enter a number of the options above: ")


def chk_GATK_indelFile(mount_path, image):
    image_name = image.split("_")[0]
    if image_name == "GATKuser1" or image_name == "GATKuser2":
        if image_name == "GATKuser1":
            GATK_path = "%sinput/GATKkit/in_b37" % mount_path
        elif image_name == "GATKuser2":
            GATK_path = "%sinput/GATKkit/in_hg19" % mount_path
        GATKfile_list = os.listdir(GATK_path)
        find_indel = False
        for f in GATKfile_list:
            if f == "indel_file.loc":
                GATK_indelfile_generated_here = False
                find_indel = True

        if not find_indel:
            GATK_indelfile_generated_here = True
            GATKfile_vcf_list = []
            for f in GATKfile_list:
                if f.endswith(".vcf"):
                    GATKfile_vcf_list.append(f)

            print "\n* Please select an INDEL file from the list below.."
            print "----------------------------------------------------------------------"
            list_index = 0
            vcfFile_list_len = len(GATKfile_vcf_list)
            for f in GATKfile_vcf_list:
                list_index = list_index + 1
                print '\t%d. %s\n' % (list_index, f)
            print "----------------------------------------------------------------------"
            while True:
                select_indel_filename = raw_input(" * Enter an integer: ")
                list_num_limit = vcfFile_list_len + 1
                if int(select_indel_filename) > 0 and int(select_indel_filename) < list_num_limit:
                    index_list = int(select_indel_filename) - 1
                    indel_filename = GATKfile_vcf_list[index_list]
                    global indel_file_path
                    indel_file_path = GATK_path + "/indel_file.loc"
                    fout = open(indel_file_path, 'w+')
                    fout.write(indel_filename)
                    fout.close()
                    break

        return GATK_indelfile_generated_here


def chk_custom_pipelineName(image):
    chk_userInput = len(image.split(':'))
    if chk_userInput > 1:
        return True
    else:
        return False


def get_repo(image, chk_custom):
    if chk_custom:
        return image
    else:
        pipeline = image.split('_')[0]
        rp = ''
        if pipeline == "ChIPseq":
            rp = "bcil/biodocklets"
            return rp
        elif pipeline == "RNAseq":
            rp = "bcil/biodocklets"
            return rp
        elif pipeline == "miRNAseq":
            rp = "bcil/mi-rna-seq"
            return rp
        elif pipeline == "GATKuser1":
            rp = "bcil/gatk"
            return rp
        elif pipeline == "GATKuser2":
            rp = "bcil/gatk"
            return rp
        elif pipeline == "QC":
            rp = "bcil/qc"
            return rp
        elif pipeline == "BAM":
            rp = "bcil/qc"
            return rp
        else:
            print "\t*************************** Error log *******************************"
            print "\tFailed to get repository name because the pipeline '%s' is not valid. \n\tPlease select the valid pipeline" % pipeline
            print "\t*********************************************************************"
            quit()
        print "\n*********************************************"
        # print " - Repository name: %s" % rp
        return rp


def get_name():
    rn = ''.join(random.choice(string.ascii_uppercase) for i in range(15))
    return rn


def get_port():
    if len(sys.argv) > 4:
        p = sys.argv[3]
        print " - Port number: %s" % sys.argv[3]
        print "**************************************************"
        return p
    else:
        while(True):
            p = raw_input(" - Port number (4 digits): ")
            p = p.strip()
            if p is not "":
                print "**************************************************"
                return p


def get_mount_path():
    if len(sys.argv) > 1:
        mp = sys.argv[1]
        mp_input = mp + '/input'
        mp_output = mp + '/output'
        mp_chk = os.path.exists(mp)
        mp_chk_input = os.path.exists(mp_input)
        mp_chk_output = os.path.exists(mp_output)
        print " - Input data path: %s" % sys.argv[1]
        if not mp_chk:
            print "Error! - Your data path (%s) does not exist." % mp
            sys.exit()
        elif mp_chk:
            if not mp_chk_input or not mp_chk_output:
                sys.exit(
                    "Error! - Your data path exists but invalid folder structure inside the path.")
    else:
        intput_chk = False
        while(not intput_chk):
            mp = raw_input(
                " --------------------------------------------------------\n -  1. /home/BCIL_pipeline_runs/\n - Please select one or type your input data path: ")
            print " --------------------------------------------------------"
            if mp == "1":
                print " - Input data path: /home/BCIL_pipeline_runs/"
                mp = "/home/BCIL_pipeline_runs/"
            # For testing purpose only.
            elif mp == "2":  # Chumby
                print " * TEST - Chumby (/usr/local/projects/data/)"
                mp = "/usr/local/projects/data/"
            ###################################################
            mp_input = mp + '/input'
            mp_output = mp + '/output'
            mp_chk = os.path.exists(mp)
            mp_chk_input = os.path.exists(mp_input)
            mp_chk_output = os.path.exists(mp_output)
            if not mp_chk:
                print "Error! - Your data path (%s) does not exist." % mp
                continue
            elif mp_chk:
                if not mp_chk_input or not mp_chk_output:
                    print "Error! - Your data path exists but invalid folder structure: missing 'input' and/or 'output' folder(s)."
                    continue
            intput_chk = True

    mp = mp.strip()
    chk = False
    if mp is not "":
        first_chr = mp[0]
        second_chr = mp[1]
        last_chr = mp[len(mp) - 1]
        if first_chr is not '/' and first_chr.isalpha():
            mp = '/' + mp
            if last_chr != '/':
                mp = mp + '/'
            chk = True
        elif first_chr is '/' and second_chr.isalpha():
            if last_chr != '/':
                mp = mp + '/'
            chk = True

    if chk:
        print " --------------------------------------------------------\n"
        return mp


def get_log_folder(mp, chk_custom):
    date = str(datetime.datetime.now()).split('.')
    timestamp = date[0].replace(' ', '_')
    loc = mp + "output/logs"
    cmd_mkdir = "mkdir -p " + loc
    try:
        subprocess.Popen(cmd_mkdir.split(), stdout=subprocess.PIPE)
        if chk_custom:
            tmp = image.split(':')[1]
            log_path = mp + 'output/logs/' + tmp + '_' + timestamp + '.txt'
            return log_path
        else:
            log_path = mp + 'output/logs/' + image + '_' + timestamp + '.txt'
            return log_path
    except:
        print "Error! - Fail to generate log folder"
        quit()


def update_log_fileName(mp, lp, cmd_mkdir):
    date = str(datetime.datetime.now()).split('.')
    timestamp = date[0].replace(' ', '_')
    timestamp = timestamp.replace(':', '-')
    new_logName = mp + 'output/logs/' + image + '_' + timestamp + '.txt'
    updated_lp = "mv %s %s" % (lp, new_logName)
    try:
        subprocess.Popen(cmd_mkdir.split(), stdout=subprocess.PIPE)
        return new_logName
    except:
        print "Error! - Fail to update the log file"
        quit()


def run_docker(ip, repo, image, image_name, port, mount_path, log_path, chk_custom, GATK_indelfile_generated_here):
    pipeline_name_prefix = image.split('_')[0]
    if chk_custom:
        repo = image.split(':')[0]
        image = image.split(':')[1]
    if pipeline_name_prefix == 'ChIPseq':
        print "************************** ChIP-Seq ***************************"
        if len(sys.argv) == 8:
            mate_std_dev = sys.argv[4]
            pvalue = sys.argv[5]
            gsize = sys.argv[6]
            bwidth = sys.argv[7]
        else:
            print "**************** Bowtie ans MACS tool options *****************"
            mate_std_dev = raw_input("* Insert size: ")
            pvalue = raw_input("* P-value: ")
            gsize = raw_input("* Effective Genome size: ")
            bwidth = raw_input("* Band width: ")
            print "*************************************************"
        print "\n**********************************************\n* Insert size: %s\n* P-value: %s\n* Effective Genome size: %s\n* Band width: %s\n**********************************************\n\n" % (mate_std_dev, pvalue, gsize, bwidth)
        cmd = "docker run -v " + mount_path + ":/home/data --name=" + image_name + " -tip " + ip + ":" + port + ":8090" + " --env insert_size=" + mate_std_dev + " --env pvalue=" + \
            pvalue + " --env gsize=" + gsize + " --env bwidth=" + bwidth + ' ' + repo + ":" + \
            image + \
            " bash /home/init.sh %s %s %s %s" % (
                mate_std_dev, pvalue, gsize, bwidth)
        # print "\n* CMD: %s\n" % cmd
    elif pipeline_name_prefix == 'RNAseq':
        print "******************** RNA-Seq ********************"
        if len(sys.argv) == 7:
            mate_std_dev = sys.argv[4]
            anchor_length = sys.argv[5]
            segment_length = sys.argv[6]
        else:
            print "**************** Tophat options *****************"
            mate_std_dev = raw_input("* Insert size: ")
            anchor_length = raw_input("* Anchor length: ")
            segment_length = raw_input("* Segment length: ")
            print "*************************************************"
        # print "\n**********************************************\n* Insert
        # size: %s\n* Anchor length: %s\n* Segment length:
        # %s\n**********************************************\n\n" %
        # (mate_std_dev, anchor_length, segment_length)
        cmd = "docker run -v " + mount_path + ":/home/data --name=" + image_name + " -tip " + ip + ":" + port + ":8090" + " --env mate_std_dev=" + \
            mate_std_dev + " --env anchor_length=" + anchor_length + " --env segment_length=" + \
            segment_length + ' ' + repo + ":" + image + " bash /home/init.sh"
    else:
        print "******************** No pipeline name ********************"
        cmd = "docker run -v " + mount_path + ":/home/data --name=" + image_name + \
            " -tip " + ip + ":" + port + ":8090 " + \
            repo + ":" + image + " bash /home/init.sh"
    start_time = time.time()
    running_info = "\n\t** %s is running.. (%s:%s) **\n\t** Mount-path: %s **\n" % (
        image, ip, port, mount_path)
    print running_info
    process = subprocess.Popen(cmd.split(), stderr=subprocess.PIPE)
    while True:
        try:
            out = process.stderr.read(1)
            if out == '' and process.poll() != None:
                break
        except KeyboardInterrupt:
            print "\n\t** Exception raised - KeyboardInterrupt ** \n\t** User stopped the pipeline(%s) **" % image_name
        except:
            exc_info = sys.exc_info()
            print "\t******************* Error log *******************"
            for msg in exc_info:
                print "\t%s" % msg
            print "\t*************************************************"

    end_time = time.time()
    total_time = int(end_time - start_time)
    close_container(image_name, mount_path, log_path, total_time,
                    GATK_indelfile_generated_here, running_info)


def close_container(image_name, mount_path, log_path, total_time, GATK_indelfile_generated_here, running_info):
    try:
        print "\t- Stopping " + image + " pipeline... "
        #stopped_image = check_output(["docker","stop",image_name])
        time.sleep(1)
        print "\t- The " + image + " pipeline terminated."
        docker_log = check_output(["docker", "logs", image_name])
        running_time_sec = total_time % 60
        running_time_min = (total_time / 60) % 60
        running_time_hour = (total_time / 60) / 60
        total_time_msg = "\n\t- Total running time (hh:mm:ss): %s:%s:%s\n\n" % (
            running_time_hour, running_time_min, running_time_sec)
        print total_time_msg
        log_data_tail = "\t** DONE **\n\n"
        print "\t- Writing log data.."
        fin = open(log_path, 'w+')
        fin.write(docker_log)
        log_header = "\n\n\t----------- Running infomation -------------\n\n"
        fin.write(log_header)
        fin.write(running_info)
        fin.write(total_time_msg)
        fin.write(log_data_tail)
        fin.close()
        #updated_logFile = update_log_fileName(mount_path,log_path)
        print "\t- To find the log file at " + log_path
        time.sleep(2)
        # print " - The running Docker pipelines below.. \n"
        #print (check_output(['docker','ps']))
        print "\n - DONE. - \n\n"
    except:
        exc_info = sys.exc_info()
        print " ******************* Error log *******************"
        for msg in exc_info:
            print "  %s" % msg
        print " *************************************************"
    finally:
        if GATK_indelfile_generated_here:
            os.remove(indel_file_path)
        os._exit(1)


if __name__ == '__main__':
    validate_run()
    ip = get_ip_address('eth0')
    image = get_image()
    chk_custom = chk_custom_pipelineName(image)
    repo = get_repo(image, chk_custom)
    port = get_port()
    mount_path = get_mount_path()
    GATK_indelfile_generated_here = chk_GATK_indelFile(mount_path, image)
    log_path = get_log_folder(mount_path, chk_custom)
    image_name = get_name()
    run_docker(ip, repo, image, image_name, port, mount_path,
               log_path, chk_custom, GATK_indelfile_generated_here)
