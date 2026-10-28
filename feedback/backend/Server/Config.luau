-- Owner-controlled server configuration. Never replicate this module.
return {
	Schema=1, StorageVersion=1, TestMode=false, NativePrivatePlaytest=false, NativeRuntimeEnabled=false,NativeRuntimeManualOnly=false,SubmissionBroadcastDisplay=false,
 NativeV2QAEnabled=false, NativeV2ManualOnly=false,
	MeasureQALatency=false, NativeQAMaxGets=16, NativeQAMaxUpdates=8, NativeQAMaxLists=1, Adapter="disabled", Environment="test", ServiceAccessEnabled=false, ApprovedUniverseId=0,ApprovedPlaceId=0,QARun="",
	MeasureQAPayloadBytes=false, -- Opt-in aggregate JSON sizes, not network transfer bytes.
	ExperimentalQAPersistedBroadcastDisplay=false, -- Unresolved cross-session compliance; never production.
	ModeratorIds={}, -- Explicit numeric Roblox UserIds only; deny everyone by default.
	MaxActive=1000, MaxArchive=1000, PublicSeconds=90*86400, AuditSeconds=180*86400,
	AuthorHistoryLimit=512, Shards=8, MembersPerShard=2000, ReportsPerShard=2000,
	Cooldown=60, DailyLimit=5, DuplicateSeconds=86400, PageSize=12, CandidateLimit=48,
	CacheLimit=128, FilterCacheSeconds=2, CursorLimit=128, CursorSeconds=60,
	MaxConcurrent=8, PerPlayerConcurrent=2, RepairBatch=2, RepairSeconds=5,
	MaxRecordBytes=900000, StoreRetries=3, RevalidateSeconds=5, IndexShards=16, IndexCacheSeconds=20,
	ManifestShards=2, SummaryShards=8, ManifestActiveLimit=500, ManifestArchiveLimit=500,
	SummariesPerShard=256, LedgerLimit=2000, PendingPerUser=32, MigrationMaxUsers=128, LegacyFrozen=false,
	ReadFlightLimit=128, WorkLimit=128, RecoverySeconds=60,
	BackgroundReadReserve=40, BackgroundWriteReserve=20, BackgroundMaxReads=24, BackgroundMaxUpdates=8,
}
