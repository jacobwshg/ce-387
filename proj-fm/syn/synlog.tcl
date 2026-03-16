history clear
project -load /home/wkm1302/387/proj_1.prj
project -load /home/wkm1302/387/proj_2.prj
project -load /home/wkm1302/387/proj_3.prj
project -load /home/wkm1302/387/proj_4.prj
project -load /home/wkm1302/387/proj_5.prj
project -load /home/wkm1302/387/proj_6.prj
project -load /home/wkm1302/387/proj_7.prj
project -load /home/wkm1302/387/proj_8.prj
project -load /home/wkm1302/387/proj_9.prj
project -load /home/wkm1302/387/proj_10.prj
project -run  
timing_corr::q_opt_corr_qii  -impl_name {/home/wkm1302/387/proj_10.prj|rev_16}  -impl_result {/home/wkm1302/387/rev_16/newproj.vqm}  -sdc_verif 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/wkm1302/387/proj_10.prj|rev_16}  -impl_result {/home/wkm1302/387/rev_16/newproj.vqm}  -load_sta 
timing_corr::pro_qii_corr  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/wkm1302/387/proj_10.prj|rev_16}  -impl_result {/home/wkm1302/387/rev_16/newproj.vqm}  -load_sta 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/wkm1302/387/proj_10.prj|rev_16}  -impl_result {/home/wkm1302/387/rev_16/newproj.vqm}  -load_sta 
project -close /home/wkm1302/387/proj_1.prj
project -close /home/wkm1302/387/proj_2.prj
project -close /home/wkm1302/387/proj_3.prj
project -close /home/wkm1302/387/proj_4.prj
project -close /home/wkm1302/387/proj_5.prj
project -close /home/wkm1302/387/proj_6.prj
project -close /home/wkm1302/387/proj_7.prj
project -close /home/wkm1302/387/proj_8.prj
project -close /home/wkm1302/387/proj_9.prj
project -close /home/wkm1302/387/proj_10.prj
