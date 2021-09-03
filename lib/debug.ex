defmodule Debug do
  def t() do 
    UrbitEx.start("http://localhost'", "sampel-sampel-somfed-baclux")
    UrbitEx.new_channel()
    UrbitEx.Channel.consume_feed(:main, self())
    Process.sleep(1000)
    {UrbitEx.get(), UrbitEx.getc()}
  end

  def loop do 
    receive do 
      thing -> IO.inspect(thing)
    end
    loop()
  end
end