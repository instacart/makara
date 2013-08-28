module MakaraExtensions

  def reset!
    release_master!
    release_forced_ids!
    release_stuck_ids!
    @context = nil
    @primary_config = nil
  end

  
end

Makara.extend MakaraExtensions