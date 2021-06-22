
select A.*, B.time2 
into z_ksr_rf_case_wave
from z_ksr_renal_fail_final A
left join mimiciii.z_khj_wave_list B
on A.subject_id = B.subject_id

--10099명
select distinct subject_id from mimiciii.z_khj_wave_list

select distinct subject_id from z_ksr_rf_case_wave

--282명 
select * from z_ksr_rf_case_wave
where time2 <= rf_starttime

select distinct subject_id from z_ksr_rf_case_wave
where time2 <= rf_starttime



select A.*, B.intime, B.outtime, B.los into z_ksr_renal_fail_list_icu from z_ksr_renal_fail_final A
left join mimiciii.icustays B
on A.icustay_id = B.icustay_id

--intime과 평균 66.6시간 (2.8일)
select extract(epoch from avg(rf_starttime - intime))/3600 from z_ksr_renal_fail_list_icu

--dialysis ICD 코드
select * from z_ksr_icd_dialysis

--2300
select * into z_ksr_not_control from (
    select distinct subject_id from z_ksr_icd_dialysis
    UNION
    select distinct subject_id from z_ksr_renal_fail_list_icu
    ) v


select distinct subject_id from mimiciii.icustays
where subject_id NOT IN (select distinct subject_id from z_ksr_not_control)
and los >= 2.8
INTERSECT
select distinct subject_id from z_ksr_renal_fail_list_icu

--21734
select subject_id, hadm_id, icustay_id, intime, outtime, los into z_ksr_renal_fail_control from mimiciii.icustays
where subject_id NOT IN (select distinct subject_id from z_ksr_not_control)
and los >= 2.8

select subject_id, hadm_id, icustay_id, to_char(rf_starttime, 'YYYYMMDDhhmiss') as rf_starttime, to_char(intime, 'YYYYMMDDhhmiss') as intime, to_char(outtime, 'YYYYMMDDhhmiss') as outtime, los
from z_ksr_renal_fail_list_icu


select subject_id, hadm_id, icustay_id, to_char(intime, 'YYYYMMDDhhmiss') as intime, to_char(outtime, 'YYYYMMDDhhmiss') as outtime, los from z_ksr_renal_fail_control


--1275
select distinct subject_id from z_ksr_renal_fail_list_icu
--1312
select distinct icustay_id from z_ksr_renal_fail_list_icu



--18582
select distinct subject_id from z_ksr_renal_fail_control
--21734
select distinct icustay_id from z_ksr_renal_fail_control

--46476
select distinct subject_id from mimiciii.icustays

select distinct icustay_id from mimiciii.icustays