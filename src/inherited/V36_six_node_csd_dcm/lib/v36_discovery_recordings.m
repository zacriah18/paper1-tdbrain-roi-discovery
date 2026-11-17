function status=v36_discovery_recordings(cfg)
status=v35_discovery_recordings(cfg);
last=min([height(status),cfg.end_row,cfg.start_row+cfg.max_recordings-1]);
if cfg.start_row>last,status=status([],:);else,status=status(cfg.start_row:last,:);end
end
