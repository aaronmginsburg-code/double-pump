-- Pure policy: do not create a service/store handle until all checks pass.
local Policy={}
function Policy.namespace(config,universeId,placeId)
	assert(config.Adapter=="roblox" and config.ServiceAccessEnabled and config.Environment=="test","Native QA is disabled")
	assert(type(config.ApprovedUniverseId)=="number" and config.ApprovedUniverseId>0 and config.ApprovedUniverseId==universeId,"Wrong QA universe")
	assert(type(config.ApprovedPlaceId)=="number" and config.ApprovedPlaceId>0 and config.ApprovedPlaceId==placeId,"Wrong QA place")
	assert(type(config.QARun)=="string" and #config.QARun>=1 and #config.QARun<=12 and config.QARun:match("^[%w_%-]+$"),"Invalid QA run")
	local name="UFeedback_qa_"..config.QARun.."_v"..config.Schema
	assert(#name<=50,"QA namespace too long")
	return name
end
function Policy.v2(config,universeId,placeId)
 assert(config.NativeV2QAEnabled==true and config.NativeV2ManualOnly==true,"V2 native startup is not authorized")
 assert(config.StorageVersion==2 and config.Schema==2 and config.TestMode==false,"V2 requires genuine native identity")
 assert(config.StoreRetries==1 and config.MeasureQAPayloadBytes==true and config.MeasureQALatency==true,"V2 requires bounded instrumented QA")
 assert(config.NativeQAMaxGets==16 and config.NativeQAMaxUpdates==8 and config.NativeQAMaxLists==1,"V2 QA ceilings changed")
 return Policy.namespace(config,universeId,placeId)
end
-- Separate installed runtime profile. Historical manual QA guards above stay sealed.
function Policy.runtime(c,universeId,placeId,isStudio)
 assert(c.NativeRuntimeEnabled==true and c.Adapter=="roblox" and c.ServiceAccessEnabled==true,"Native runtime disabled")
 assert(c.StorageVersion==2 and c.Schema==2 and c.TestMode==false,"Native runtime requires real Storage V2")
 assert(c.Environment=="production" or c.Environment=="qa","Unknown runtime environment")
 assert(c.ApprovedUniverseId==universeId and universeId>0,"Wrong runtime universe")
 assert(c.ApprovedPlaceId==placeId and placeId>0,"Wrong runtime place")
 assert(not c.NativeV2QAEnabled and not c.ExperimentalQAPersistedBroadcastDisplay,"Mixed native activation profiles")
 assert(c.Environment~="production" or not isStudio,"Production storage forbidden from Studio")
 local name=c.StoreNamespace
 assert(type(name)=="string" and #name<=50 and name:match("^UFeedback_[%w_]+_v2$"),"Invalid runtime namespace")
 if c.Environment=="qa" then
  assert(name:match("^UFeedback_qa_"),"QA namespace required")
  assert(c.StoreRetries==1,"QA requires single-attempt storage")
  if c.NativePrivatePlaytest==true then
   assert(c.NativeRuntimeManualOnly==false,"Private playtest requires explicit automatic profile")
   assert(type(c.PrivateSourceUniverseId)=="number" and c.PrivateSourceUniverseId>0 and c.PrivateSourceUniverseId~=universeId,"Private copy cannot use source universe")
   assert(type(c.PrivateSourcePlaceId)=="number" and c.PrivateSourcePlaceId>0 and c.PrivateSourcePlaceId~=placeId,"Private copy cannot use source place")
   assert(c.NativeRuntimeMaxGets==2000 and c.NativeRuntimeMaxUpdates==300 and c.NativeRuntimeMaxLists==16,"Private playtest ceilings changed")
  else
   assert(c.NativeRuntimeManualOnly==true,"QA requires bounded manual entrypoint")
   assert(c.NativeRuntimeMaxGets==64 and c.NativeRuntimeMaxUpdates==40 and c.NativeRuntimeMaxLists==2,"QA runtime ceilings changed")
  end
  assert(c.MeasureQAPayloadBytes and c.MeasureQALatency,"QA instrumentation required")
 else
  assert(not name:match("^UFeedback_qa_") and c.NativeRuntimeManualOnly~=true and c.NativePrivatePlaytest~=true,"Production profile mismatch")
  assert(not c.MeasureQAPayloadBytes and not c.MeasureQALatency,"QA instrumentation cannot enter production")
 end
 return name
end
return Policy
