
all:
	fcc b -d -t nes -o miku.nes miku.fc 

clean:
	rm -rf miku.nes miku.map .fc-build

