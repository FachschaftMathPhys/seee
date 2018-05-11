class DataMigrationToCensor < ActiveRecord::Migration[5.1]
  def up
    Prof.all.each do |u|
      if u.publish_ok
        u.censor = :none
      else
        u.censor = :everything
      end
      u.save
    end

    #
    
  end

  def down
    warn "Rolling back data migration to :censor is not actually possible."
  end
end
