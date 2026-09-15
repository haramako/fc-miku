FCC = "fcc"

task :default do 
  sh FCC, "build", "-d", "-t", "nes", "-o", "miku.nes", "miku.fc"
end

task :clean do
  rm_rf ["miku.nes", "miku.map", ".fc-build"]
end
