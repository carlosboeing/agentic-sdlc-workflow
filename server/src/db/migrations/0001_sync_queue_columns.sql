ALTER TABLE `sync_queue` ADD COLUMN `idempotency_key` text;--> statement-breakpoint
ALTER TABLE `sync_queue` ADD COLUMN `item_id` integer;
