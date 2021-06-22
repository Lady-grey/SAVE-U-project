select * from mimiciii.d_labitems
where fluid = 'Blood'
order by label

select * from mimiciii.d_labitems
where label like 'B%'

select * from mimiciii.d_items
where label like '%BUN%'

select * from mimiciii.d_items
where label like '%creatinine%'

select * from mimiciii.d_items
where label like '%serum%'

select * from mimiciii.d_items
where label like '%sodium%'

select * from mimiciii.d_items
where label like '%PH%'

/*
MIMIC 3 
--d_labitems
creatinine itemid 50912
PH itemid 50820
Potassium 50971

--chartevent
BUN itemid 1162, 781, 3737 carevue
    itemid 227000, 225624 metavision

potassium (serum) 227442 metavision

PH 1673 carevue
    228243, 223830 metavision


*/

select subject_id, hadm_id, itemid, charttime, valuenum, valueuom into z_ksr_RF_labevents from mimiciii.labevents
where itemid IN (50912, 50820, 50971)

select * from mimiciii.chartevents limit 100

select subject_id, hadm_id, icustay_id, itemid, charttime, valuenum, valueuom into z_ksr_rf_chartevents
from mimiciii.chartevents
where itemid IN (1162, 781, 3737, 225624, 227442, 1673, 228243, 223830) 

--------------------------------------------------------------------------------------------------------------------------------------------
--labevents 동일한 검체 결과 통일된 컬럼명으로 변경
select * from z_ksr_rf_labevents limit 10

select itemid, valueuom, count(*) from z_ksr_rf_labevents
group by itemid, valueuom

ALTER TABLE z_ksr_rf_labevents RENAME COLUMN valueuom TO label;

update z_ksr_rf_labevents
set label='pH'
where itemid = 50820

update z_ksr_rf_labevents
set label='sCr'
where itemid = 50912

update z_ksr_rf_labevents
set label='potassium'
where itemid = 50971

select * from z_ksr_rf_labevents limit 100

--PIVOT하여 각 날짜에 해당하는 값을 펼침
SELECT subject_id, charttime,
       max((CASE WHEN label = 'pH' THEN valuenum END)) AS "pH",
       max((CASE WHEN label = 'potassium' THEN valuenum END)) AS "potassium",
       max((CASE WHEN label = 'sCr' THEN valuenum END)) AS "sCr"
into z_ksr_rf_labevents_pivot
FROM z_ksr_rf_labevents
GROUP BY subject_id, charttime;


--------------------------------------------------------------------------------------------------------------------------------------------
--chartevents 동일한 검체 결과 통일된 컬럼명으로 변경
select * from z_ksr_rf_chartevents limit 10

select itemid, valueuom, count(*) from z_ksr_rf_chartevents
group by itemid, valueuom

ALTER TABLE z_ksr_rf_chartevents RENAME COLUMN valueuom TO label;

update z_ksr_rf_chartevents
set label='BUN'
where itemid IN (1162, 781, 3737, 225624)

update z_ksr_rf_chartevents
set label='potassium'
where itemid = 227442

update z_ksr_rf_chartevents
set label='pH'
where itemid IN (1673, 228243, 223830)

select * from z_ksr_rf_chartevents limit 100

--PIVOT하여 각 날짜에 해당하는 값을 펼침
SELECT subject_id, icustay_id, charttime,
       max((CASE WHEN label = 'pH' THEN valuenum END)) AS "pH",
       max((CASE WHEN label = 'potassium' THEN valuenum END)) AS "potassium",
       max((CASE WHEN label = 'BUN' THEN valuenum END)) AS "BUN"
into z_ksr_rf_chartevents_pivot
FROM z_ksr_rf_chartevents
GROUP BY subject_id, icustay_id, charttime;

select * from z_ksr_rf_labevents_pivot limit 100

select * from z_ksr_rf_chartevents_pivot limit 100

select * from INFORMATION_SCHEMA.COLUMNS
where table_name = 'z_ksr_rf_chartevents_pivot'

--------------------------------------------------------------------------------------------------------------------------------------------

--sCr baseline
select subject_id, charttime, "sCr" into z_ksr_scr from z_ksr_rf_labevents_pivot
where "sCr" is not null

select subject_id, icustay_id, intime, outtime, los into z_ksr_icu_patient from mimiciii.icustays

select A.*, B.icustay_id, intime, outtime into z_ksr_scr_intime
from z_ksr_scr as A
left JOIN z_ksr_icu_patient as B
on A.subject_id = B.subject_id

select *, row_number() over (partition by icustay_id order by "sCr") as scr_RN 
into z_ksr_scr_intime_RN
from (select * from z_ksr_scr_intime WHERE intime <= charttime and charttime <= outtime) v

select subject_id, icustay_id, intime, charttime, "sCr" as sCr_base into z_ksr_scr_intime_first from z_ksr_scr_intime_RN
where scr_RN = 1

select * from z_ksr_scr_intime_first

--------------------------------------------------------------------------------------------------------------------------------------------

select * into z_ksr_rf_chart from z_ksr_rf_chartevents_pivot
where ("pH" < 7.2 or "potassium" >= 6.0 or "BUN" >= 60)

select * from z_ksr_rf_chart limit 100

select A.*, B.icustay_id,  intime, outtime into z_ksr_rf_lab_icu
from z_ksr_rf_labevents_pivot as A
left JOIN z_ksr_icu_patient as B
on A.subject_id = B.subject_id
 
select * from z_ksr_rf_lab_icu limit 100

select subject_id, icustay_id, intime, outtime, charttime, "pH", "potassium","sCr" into z_ksr_rf_lab_in_icu
from z_ksr_rf_lab_icu 
where intime <= charttime and charttime <= outtime

select * from z_ksr_rf_lab_in_icu limit 100

select A.subject_id, A.icustay_id, charttime, "pH","potassium","sCr", B.scr_base into z_ksr_rf_lab_in_icu_2
from z_ksr_rf_lab_in_icu as A
left JOIN (select icustay_id, scr_base from z_ksr_scr_intime_first) as B
on A.icustay_id = B.icustay_id

select * into z_ksr_rf_lab from z_ksr_rf_lab_in_icu_2 
where ("pH" < 7.2 or "potassium" >= 6.0 or "sCr" >= scr_base*2)

select * from z_ksr_rf_lab limit 100

select * from z_ksr_rf_chart limit 100

select A.subject_id, A.icustay_id, A.charttime, A."pH",A."potassium",B."BUN",A."sCr",A.scr_base 
into z_ksr_rf_total_lab
from z_ksr_rf_lab A
FULL JOIN
z_ksr_rf_chart B
on A.subject_id = B.subject_id and A.icustay_id = B.icustay_id and A.charttime = B.charttime

select * from z_ksr_rf_total_lab
order by icustay_id, charttime limit 100 

--9916명
select distinct subject_id from z_ksr_rf_total_lab

--11189건
select distinct icustay_id from z_ksr_rf_total_lab

--------------------------------------------------------------------------------------------------------------------------------------------
select * from mimiciii.d_items
where label like '%urine out%'
and linksto = 'outputevents'

select * from mimiciii.d_items
where label like '%foley%'
and linksto = 'outputevents'

/*
 40055, -- "Urine Out Foley"
  43175, -- "Urine ."
  40069, -- "Urine Out Void"
  40094, -- "Urine Out Condom Cath"
  40715, -- "Urine Out Suprapubic"
  40473, -- "Urine Out IleoConduit"
  40085, -- "Urine Out Incontinent"
  40057, -- "Urine Out Rt Nephrostomy"
  40056, -- "Urine Out Lt Nephrostomy"
  40405, -- "Urine Out Other"
  40428, -- "Urine Out Straight Cath"
  40086,--	Urine Out Incontinent
  40096, -- "Urine Out Ureteral Stent #1"
  40651, -- "Urine Out Ureteral Stent #2"

  -- these are the most frequently occurring urine output observations in MetaVision
  226559, -- "Foley"
  226560, -- "Void"
  226561, -- "Condom Cath"
  226584, -- "Ileoconduit"
  226563, -- "Suprapubic"
  226564, -- "R Nephrostomy"
  226565, -- "L Nephrostomy"
  226567, --	Straight Cath
  226557, -- R Ureteral Stent
  226558, -- L Ureteral Stent
  227488, -- GU Irrigant Volume In
  227489  -- GU Irrigant/Urine Volume Out
  */

select subject_id, hadm_id, icustay_id, charttime, value, valueuom into z_ksr_rf_urine_output
from mimiciii.outputevents
where icustay_id IN (select distinct icustay_id from z_ksr_rf_total_lab)
and itemid IN (40055, 40055, 40069, 40094, 40715, 40473, 40085,
40057, 40056, 40405, 40428, 40086, 40096, 40651,
226559, 226560, 226561, 226584, 226563, 226564,
226565, 226567, 226557, 226558, 227488, 227489) 
and value < 30 

select * from z_ksr_rf_urine_output
order by icustay_id, charttime

select icustay_id, count(value) as count into z_ksr_rf_urine_count from z_ksr_rf_urine_output
group by icustay_id

select * , row_number() over (partition by icustay_id order by charttime) as urine_RN 
into z_ksr_rf_urine_RN
from z_ksr_rf_urine_output
where icustay_id IN (select distinct icustay_id from z_ksr_rf_urine_count where count >= 6)
order by icustay_id, charttime

select * from z_ksr_rf_urine_RN limit 10

select *, LEAD(charttime, 5, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) as after_6rows, 
LEAD(charttime, 5, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) - charttime as diff_hour into z_ksr_rf_uo_lead
from z_ksr_rf_urine_rn

select * 
into z_ksr_urine_temp1
from z_ksr_rf_uo_lead
where EXTRACT(epoch FROM diff_hour)/3600 <= 6
or after_6rows is null
order by icustay_id, charttime

select *,LEAD(charttime, 1, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) as after_1rows,
LEAD(charttime, 1, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) - charttime as diff_hour_2 into z_ksr_urine_temp2
from z_ksr_urine_temp1


select * into z_ksr_urine_temp3
from z_ksr_urine_temp2
where EXTRACT(epoch FROM diff_hour_2)/3600 <= 1
order by icustay_id, charttime

select subject_id, hadm_id, icustay_id, charttime, value from z_ksr_urine_temp3
order by icustay_id, charttime

select subject_id, hadm_id, icustay_id, charttime, value, charttime + interval '1hours' as add_1h, 
lead(charttime, 1, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) as after_1rows
into z_ksr_urine_temp4
from z_ksr_urine_temp3

select * into z_ksr_urine_temp5
from z_ksr_urine_temp4
where after_1rows <= add_1h
or after_1rows is null
order by icustay_id, charttime


select icustay_id, count(value) as count into z_ksr_urine_temp5_count from z_ksr_urine_temp5
group by icustay_id

select subject_id, hadm_id, icustay_id, charttime, value, charttime + interval '6hours' as add_6h, 
lead(charttime, 5, NULL) OVER (PARTITION BY icustay_id ORDER BY charttime) as after_5rows
into z_ksr_urine_temp6
from z_ksr_urine_temp5
where icustay_id IN (select distinct icustay_id from z_ksr_urine_temp5_count where count >=6)


select *, row_number() over (partition by icustay_id order by charttime) as urine_RN into z_ksr_urine_temp7 from z_ksr_urine_temp6
where after_5rows <= add_6h
order by icustay_id, charttime

select subject_id, hadm_id, icustay_id, charttime, value, row_number() over (partition by icustay_id order by charttime) as urine_RN INTO z_ksr_urine_final_RN
from z_ksr_urine_temp6
where icustay_id IN (select distinct icustay_id from z_ksr_urine_temp7 where urine_RN = 1)
order by icustay_id, charttime

select subject_id, hadm_id, icustay_id, charttime as RF_starttime into z_ksr_renal_fail_list from z_ksr_urine_final_RN
where urine_RN = 1

--1389
select distinct subject_id from z_ksr_renal_fail_list

--1435
select distinct icustay_id from z_ksr_renal_fail_list

--------------------------------------------------------------------------------------------------------------------------------------------

--dialysis ICD 코드
select * from mimiciii.d_icd_diagnoses
where short_title like '%dialysis%'

select * from mimiciii.d_icd_diagnoses
where icd9_code like '%585%'

select * from mimiciii.d_icd_procedures
where short_title like '%dialysis%'

select subject_id, hadm_id, icd9_code into z_ksr_icd_dialysis from mimiciii.diagnoses_icd 
where icd9_code IN ('5855', '5856', 'V4511', '3995') 

--1148명 
select distinct subject_id from z_ksr_icd_dialysis

--procedureevents or datetimeevents 에서 확인  
select * from mimiciii.d_items
where label like '%dialysis%'

--225128 datetimeevents
--225441 procedureevents_mv

select * from mimiciii.d_items
where itemid IN (225441, 225128)

select * , row_number() over (partition by icustay_id order by value) as hemodia_RN 
into z_ksr_hemodialysis
from (select subject_id, hadm_id, icustay_id, itemid, value from mimiciii.datetimeevents
where itemid = 225128) v

select subject_id, hadm_id, icustay_id, value as first_hemodia 
into z_ksr_hemodialysis_first
from z_ksr_hemodialysis
where hemodia_RN = 1


--none...
select * from mimiciii.procedureevents_mv
where itemid = 225128 

--crrt initiate
/* -- Below indicates that a new instance of CRRT has started
  , max(
    case
      -- System Integrity
      when ce.itemid = 224146 and value in ('New Filter','Reinitiated')
        then 1
      when ce.itemid = 665 and value in ('Initiated')
*/

select * from mimiciii.d_items
where itemid IN (224146, 665)

select subject_id, hadm_id, icustay_id, itemid, charttime, row_number() over (partition by icustay_id order by charttime) as crrt_RN 
into crrt_ini
from mimiciii.chartevents
where itemid IN (224146, 665)
and value IN ('New Filter','Reinitiated','Initiated')


select * from crrt_ini

select subject_id, hadm_id, icustay_id, charttime as first_hemodia 
into z_ksr_crrt_first
from crrt_ini
where crrt_RN = 1

--------------------------------------------------------------------------------------------------------------------------------------------
--dialysis 제외

select * into z_ksr_hemodialysis_union
from (
    select * from z_ksr_hemodialysis_first  
    UNION
    select * from z_ksr_crrt_first
) v

select A.*, B.first_hemodia into z_ksr_rf_exclude
from z_ksr_renal_fail_list A
left JOIN (select icustay_id, first_hemodia from z_ksr_hemodialysis_union) B
on A.icustay_id = B.icustay_id
where first_hemodia <= rf_starttime

select * from z_ksr_rf_exclude

select * INTO z_ksr_renal_fail_final
from z_ksr_renal_fail_list
where icustay_id NOT IN (select distinct icustay_id from z_ksr_rf_exclude)

--1312
select distinct icustay_id from z_ksr_renal_fail_final

--1275명
select distinct subject_id from z_ksr_renal_fail_final