defmodule UrbitEx.Utils do
  alias UrbitEx.Resource

  @moduledoc """
  Utils module with some useful functions, such as a tokenizer for graph store, regex for urls and @ps, etc.
  """

  @doc """
  Eyre endpoints which return a boolean are rather weird. Instead of returning true or false,
  they return a 200 with null body if true, or a 500 if false.
  See `API.Graph.exists?` or `API.Settings.has_bucket?` and others.
  """
  def eyre_boolean?(response_status_code) do
    case response_status_code do
      200 -> true
      500 -> false
      _ -> :error
    end
  end

  def random_hex(num) do
    :crypto.strong_rand_bytes(num) |> Base.encode16(case: :lower)
  end

  # TODO need romanization here
  def group_name(string) do
    string |> String.downcase() |> String.replace(" ", "-")
  end

  def channel_name(string) do
    name = string |> String.downcase() |> String.replace(" ", "-")
    "#{name}-#{Enum.random(1_000..9_999)}"
  end

  # TODO
  def da_to_date(da) do
    da
  end

  def validate_da(string) do
    full_regex = ~r|^~\d{4}\.\d{1,2}\.\d{1,2}\.\.\d{1,2}\.\d{1,2}\.\d{1,2}\.\.\w{4}$|
    partial_regex = ~r|^~\d{4}\.\d{1,2}\.\d{1,2}$|

    cond do
      Regex.match?(full_regex, string) -> parse_full_da(string)
      Regex.match?(partial_regex, string) -> parse_partial_da(string)
      true -> DateTime.utc_now()
    end
  end

  def parse_full_da(da) do
    r = ~r|^~(\d{4})\.(\d{1,2})\.(\d{1,2})\.\.(\d{1,2})\.(\d{1,2})\.(\d{1,2})\.\.(\w{4})$|
    [[_string, year, month, day, hour, minute, second, _milisecond_hash]] = Regex.scan(r, da)
    date = da_date_to_date(year, month, day)
    isotime = [hour, minute, second] |> Enum.join(":")
    {:ok, time} = Time.from_iso8601(isotime)
    DateTime.new!(date, time)
  end

  def parse_partial_da(da) do
    r = ~r|^~(\d{4})\.(\d{1,2})\.(\d{1,2})$|
    [[_string, year, month, day]] = Regex.scan(r, da)
    date = da_date_to_date(year, month, day)
    time = Time.new(0, 0, 0)
    DateTime.new!(date, time)
  end

  defp da_date_to_date(year, month, day) do
    pad = fn x -> if String.length("#{x}") < 2, do: "0#{x}", else: x end
    isodate = [year, month, day] |> Enum.map(&pad.(&1)) |> Enum.join("-")
    {:ok, d} = Date.from_iso8601(isodate)
    d
  end

  def date_to_da(date) do
    # miliseconds seem to be hex encoded
    miliseconds = 0000
    pad = fn n -> String.pad_leading("#{n}", 2, "0") end

    ~s(~#{date.year}.#{date.month}.#{date.day}..#{pad.(date.hour)}.#{pad.(date.minute)}.#{pad.(date.second)}..#{miliseconds})
  end

  def calculate_index(unix_time) do
    da_unix_epoch = 170_141_184_475_152_167_957_503_069_145_530_368_000
    da_second = 18_446_744_073_709_551_616
    time_since_epoch = (unix_time * da_second / 1000) |> round
    da_unix_epoch + time_since_epoch
  end

  def break_index(""), do: ""

  def break_index(index_string) do
    index_string
    |> String.split("/", trim: true)
    |> Enum.map(&do_break_index/1)
    |> Enum.join("")
  end

  defp do_break_index(index) do
    index
    |> String.to_integer
    |> int_to_ud()
    |> then(&("/" <> &1))
  end

  def parse_index(index) when is_binary(index) do
    index
    |> String.replace(".", "")
    |> String.to_integer()
    |> parse_index()
  end

  def parse_index(index) when is_integer(index) do
    da_unix_epoch = 170_141_184_475_152_167_957_503_069_145_530_368_000
    da_second = 18_446_744_073_709_551_616

    index
    |> Kernel.-(da_unix_epoch)
    |> Kernel./(da_second)
    |> Kernel.*(1000)
    |> round()
    |> DateTime.from_unix!(:millisecond)
  end

  ## graph store post contents tokenizer
  @doc """
    Takes a long string and breaks it up into tokens to be stored into graph-store.
    Graph-store tokens can be `text`, `url`, `mention`, `reference` or `code`.
    Returns a list of token maps to pass to any graph-store post function.
  """
  def tokenize(string) do
    {string, []}
    |> extract(:reference)
    |> extract(:mention)
    |> extract(:url)
    |> extract(:text)
  end

  def extract({string, contents}, :text) do
    uids = contents |> Enum.map(fn {uid, _token} -> String.replace(uid, ";", "") end)

    string
    |> String.split(";;", trim: true)
    |> Enum.map(fn x ->
      if x in uids,
        do: elem(Enum.find(contents, fn {uid, _token} -> uid == ";;#{x};;" end), 1),
        else: %{text: x}
    end)
  end

  def extract({string, contents}, type) do
    r = regexes()[type]
    matches = Regex.scan(r, string)

    Enum.reduce(matches, {string, contents}, fn match, acc ->
      extract2(acc, match, type)
    end)
  end

  def extract2({string, contents}, match, :reference) do
    [m, group_ship, group_name, channel_ship, channel_name, index] = match
    uid = token_uid()

    remnant = String.replace(string, m, uid)

    group = UrbitEx.Resource.new(group_ship, group_name)
    channel = UrbitEx.Resource.new(channel_ship, channel_name)

    token =
      {uid,
       %{
         reference: %{
           graph: %{
             graph: UrbitEx.Resource.to_url(channel),
             group: UrbitEx.Resource.to_url(group),
             index: "/#{index}"
           }
         }
       }}

    {remnant, [token | contents]}
  end

  def extract2({string, contents}, match, :mention) do
    [ship] = match

    if validate_patp(ship) do
      uid = token_uid()
      remnant = String.replace(string, ship, uid)
      token = {uid, %{mention: ship}}
      {remnant, [token | contents]}
    else
      {string, contents}
    end
  end

  def extract2({string, contents}, match, :url) do
    [url] = match
    uid = token_uid()

    remnant = String.replace(string, url, uid)
    token = {uid, %{url: url}}
    {remnant, [token | contents]}
  end

  # def extract2({string, contents}, match, :url), do: {string, contents}

  defp token_uid do
    ";;#{:rand.uniform(10000) |> Integer.to_string() |> Base.encode64()};;"
  end

  ## Urbit @p logic

  @doc """
    Adds tilde to an Urbit ship name if it lacks one.
    Takes a string.
    Returns a string.
  """
  def add_tilde(ship) do
    case Regex.match?(~r(^~), ship) do
      true -> ship
      false -> "~#{ship}"
    end
  end

  @doc """
    Removes tilde from an Urbit ship name if it has one.
    Takes a string.
    Returns a string.
  """
  def remove_tilde(patp), do: patp |> String.replace(~r([~^]), "")
  @doc """
    Abbreviates comet and moon names following Landscape practice.
    Takes a string.
    Returns a string.
  """
  def abbreviate_patp(patp) do
    cond do
      String.length(patp) < 16 ->
        patp

      String.length(patp) < 30 ->
        p = syllabize(patp)
        "~#{Enum.at(p, 0)}#{Enum.at(p, 1)}^#{Enum.at(p, -2)}#{Enum.at(p, -1)}"

      String.length(patp) == 57 ->
        p = syllabize(patp)
        "~#{Enum.at(p, 0)}#{Enum.at(p, 1)}_#{Enum.at(p, -2)}#{Enum.at(p, -1)}"

      true ->
        :error
    end
  end

  @doc """
    Validates that a string is a valid Urbit shipname.
    It ignores tildes and other punctuation.
    Takes a string, returns a clean shipname if valid, false if invalid.
  """
  def validate_patp(shipname) do
    with {:ok, patp} <- validate_header(shipname),
         {:ok, stripped} <- validate_length(patp),
         true <- syllabize(stripped) do
      patp
    else
      _ -> false
    end
  end

  defp validate_header(shipname) do
    case Regex.match?(~r(^[~|\w]), shipname) do
      true -> {:ok, add_tilde(shipname)}
      false -> false
    end
  end

  defp validate_length(patp) do
    clean = patp |> String.replace(~r([~^-]), "")
    len = String.length(clean)
    right_length = len > 2 && len < 49 && rem(len, 3) == 0

    case right_length do
      true -> {:ok, clean}
      false -> false
    end
  end

  defp syllabize(stripped) do
    syllables = Regex.scan(~r(.{3}), stripped) |> List.flatten()
    cond do
      length(syllables) == 1 -> syllable_list().s |> Enum.member?(Enum.at(syllables, 0))
      length(syllables) == 2 -> check_bisyllable(syllables)
      length(syllables) < 17 && rem(length(syllables), 2) == 0 -> check_long(syllables)
      true -> false
    end
  end
  @doc """
    Returns the ship type given a ship name.
    Takes a string, returns an atom with the ship class.
  """
  def ship_type(shipname) do
    shipname
    |> String.replace(~r/\W/, "")
    |> then(& Regex.scan(~r(.{3}), &1))
    |> List.flatten()
    |> length
    |> case do
      1 -> :galaxy
      2 -> :star
      4 -> :planet
      6 -> :moon
      8 -> :moon
    end
  end
  @doc """
    Checks whether the passed ship name belongs to a comet.
    Takes a string, returns `:ok` if not a comet, `:gtfo` if a comet.
  """
  def no_comets(shipname) do
    stripped = String.replace(shipname, ~r/\W/, "")
    syllables = Regex.scan(~r(.{3}), stripped)
     |> List.flatten()

    cond do
      length(syllables) > 8 -> :gtfo
      true -> :ok
    end
  end

  defp check_long(syllables) do
    join = syllables |> Enum.join()

    pairs =
      Regex.scan(~r(.{6}), join)
      |> List.flatten()
      |> Enum.map(fn x -> Regex.scan(~r/.{3}/, x) |> List.flatten() end)

    Enum.all?(pairs, fn x -> check_bisyllable(x) end)
  end

  defp check_bisyllable(pair) do
    [pref, suf] = pair
    syllable_list().p |> Enum.member?(pref) && syllable_list().s |> Enum.member?(suf)
  end

  ## other
  @doc """
    Breaks an integer into a string resembling the hoon @ud type (long integer with a period every three digits, e.g. "170.123.456")
    Takes an integer, returns a string.
  """
  def int_to_ud(int) do
    int
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  # TODO this gives the @q number. @p are ciphered.
  def patp(patp) do
    syllables = patp |> syllabize

    syllables
    |> Enum.with_index()
    |> Enum.map(fn {syllable, index} ->
      type = if rem(index, 2) != 0 || length(syllables) == 1, do: :s, else: :p
      hex(syllable, type)
    end)
    |> Enum.join()
    |> String.to_charlist()
    |> List.to_integer(16)
  end

  def hex(syllable, type) do
    index = Enum.find_index(syllable_list()[type], &(&1 == syllable))
    Integer.to_string(index, 16) |> String.pad_leading(2, "0")
  end

  @doc """
    Produces an Urbit permalink as used by Landscape.
    Takes a group Resource struct, a channel Resource struct, and an index string.
    Returns an Urbit web+urbitgraph permalink.
  """
  def get_permalink(group, channel, index) do
    ~s|web+urbitgraph://group/#{group.ship}/#{group.name}/graph/#{channel.ship}/#{channel.name}#{index}|
  end

  @doc """
    Produces a reference map as used by graph store from a permalink string.
    Takes a permalink string. Returns a reference map.
  """
  def parse_permalink(permalink) do
    ["web+urbitgraph:", "group", gship, gname, "graph", csip, cname | indexes] =
      String.split(permalink, "/", trim: true)
    index = Enum.join(indexes, "/")

    %{
      reference: %{
        group: Resource.new(gship, gname) |> Resource.to_url(),
        graph: Resource.new(csip, cname) |> Resource.to_url(),
        index: "/" <> index
      }
    }
  end

  defp regexes do
    %{
      text: ~r|;;.+;;|u,
      # url: ~r/[(http)|(https)]+:\/\/.+\.\S+/u,
      url: ~r/https?+:\/\/.+\.\S+/u,
      mention: ~r/~[bcdfghjlmnprstwz][aeiouy][\w^-]+/,
      code: ~r/`.+`/,
      reference: ~r|web\+urbitgraph:\/\/group\/(~.+?)\/(.+?)\/graph\/(~.+?)\/(.+?)\/([\d^\/]+)|
    }
  end

  defp syllable_list do
    %{
      p: [
        "doz",
        "mar",
        "bin",
        "wan",
        "sam",
        "lit",
        "sig",
        "hid",
        "fid",
        "lis",
        "sog",
        "dir",
        "wac",
        "sab",
        "wis",
        "sib",
        "rig",
        "sol",
        "dop",
        "mod",
        "fog",
        "lid",
        "hop",
        "dar",
        "dor",
        "lor",
        "hod",
        "fol",
        "rin",
        "tog",
        "sil",
        "mir",
        "hol",
        "pas",
        "lac",
        "rov",
        "liv",
        "dal",
        "sat",
        "lib",
        "tab",
        "han",
        "tic",
        "pid",
        "tor",
        "bol",
        "fos",
        "dot",
        "los",
        "dil",
        "for",
        "pil",
        "ram",
        "tir",
        "win",
        "tad",
        "bic",
        "dif",
        "roc",
        "wid",
        "bis",
        "das",
        "mid",
        "lop",
        "ril",
        "nar",
        "dap",
        "mol",
        "san",
        "loc",
        "nov",
        "sit",
        "nid",
        "tip",
        "sic",
        "rop",
        "wit",
        "nat",
        "pan",
        "min",
        "rit",
        "pod",
        "mot",
        "tam",
        "tol",
        "sav",
        "pos",
        "nap",
        "nop",
        "som",
        "fin",
        "fon",
        "ban",
        "mor",
        "wor",
        "sip",
        "ron",
        "nor",
        "bot",
        "wic",
        "soc",
        "wat",
        "dol",
        "mag",
        "pic",
        "dav",
        "bid",
        "bal",
        "tim",
        "tas",
        "mal",
        "lig",
        "siv",
        "tag",
        "pad",
        "sal",
        "div",
        "dac",
        "tan",
        "sid",
        "fab",
        "tar",
        "mon",
        "ran",
        "nis",
        "wol",
        "mis",
        "pal",
        "las",
        "dis",
        "map",
        "rab",
        "tob",
        "rol",
        "lat",
        "lon",
        "nod",
        "nav",
        "fig",
        "nom",
        "nib",
        "pag",
        "sop",
        "ral",
        "bil",
        "had",
        "doc",
        "rid",
        "moc",
        "pac",
        "rav",
        "rip",
        "fal",
        "tod",
        "til",
        "tin",
        "hap",
        "mic",
        "fan",
        "pat",
        "tac",
        "lab",
        "mog",
        "sim",
        "son",
        "pin",
        "lom",
        "ric",
        "tap",
        "fir",
        "has",
        "bos",
        "bat",
        "poc",
        "hac",
        "tid",
        "hav",
        "sap",
        "lin",
        "dib",
        "hos",
        "dab",
        "bit",
        "bar",
        "rac",
        "par",
        "lod",
        "dos",
        "bor",
        "toc",
        "hil",
        "mac",
        "tom",
        "dig",
        "fil",
        "fas",
        "mit",
        "hob",
        "har",
        "mig",
        "hin",
        "rad",
        "mas",
        "hal",
        "rag",
        "lag",
        "fad",
        "top",
        "mop",
        "hab",
        "nil",
        "nos",
        "mil",
        "fop",
        "fam",
        "dat",
        "nol",
        "din",
        "hat",
        "nac",
        "ris",
        "fot",
        "rib",
        "hoc",
        "nim",
        "lar",
        "fit",
        "wal",
        "rap",
        "sar",
        "nal",
        "mos",
        "lan",
        "don",
        "dan",
        "lad",
        "dov",
        "riv",
        "bac",
        "pol",
        "lap",
        "tal",
        "pit",
        "nam",
        "bon",
        "ros",
        "ton",
        "fod",
        "pon",
        "sov",
        "noc",
        "sor",
        "lav",
        "mat",
        "mip",
        "fip"
      ],
      s: [
        "zod",
        "nec",
        "bud",
        "wes",
        "sev",
        "per",
        "sut",
        "let",
        "ful",
        "pen",
        "syt",
        "dur",
        "wep",
        "ser",
        "wyl",
        "sun",
        "ryp",
        "syx",
        "dyr",
        "nup",
        "heb",
        "peg",
        "lup",
        "dep",
        "dys",
        "put",
        "lug",
        "hec",
        "ryt",
        "tyv",
        "syd",
        "nex",
        "lun",
        "mep",
        "lut",
        "sep",
        "pes",
        "del",
        "sul",
        "ped",
        "tem",
        "led",
        "tul",
        "met",
        "wen",
        "byn",
        "hex",
        "feb",
        "pyl",
        "dul",
        "het",
        "mev",
        "rut",
        "tyl",
        "wyd",
        "tep",
        "bes",
        "dex",
        "sef",
        "wyc",
        "bur",
        "der",
        "nep",
        "pur",
        "rys",
        "reb",
        "den",
        "nut",
        "sub",
        "pet",
        "rul",
        "syn",
        "reg",
        "tyd",
        "sup",
        "sem",
        "wyn",
        "rec",
        "meg",
        "net",
        "sec",
        "mul",
        "nym",
        "tev",
        "web",
        "sum",
        "mut",
        "nyx",
        "rex",
        "teb",
        "fus",
        "hep",
        "ben",
        "mus",
        "wyx",
        "sym",
        "sel",
        "ruc",
        "dec",
        "wex",
        "syr",
        "wet",
        "dyl",
        "myn",
        "mes",
        "det",
        "bet",
        "bel",
        "tux",
        "tug",
        "myr",
        "pel",
        "syp",
        "ter",
        "meb",
        "set",
        "dut",
        "deg",
        "tex",
        "sur",
        "fel",
        "tud",
        "nux",
        "rux",
        "ren",
        "wyt",
        "nub",
        "med",
        "lyt",
        "dus",
        "neb",
        "rum",
        "tyn",
        "seg",
        "lyx",
        "pun",
        "res",
        "red",
        "fun",
        "rev",
        "ref",
        "mec",
        "ted",
        "rus",
        "bex",
        "leb",
        "dux",
        "ryn",
        "num",
        "pyx",
        "ryg",
        "ryx",
        "fep",
        "tyr",
        "tus",
        "tyc",
        "leg",
        "nem",
        "fer",
        "mer",
        "ten",
        "lus",
        "nus",
        "syl",
        "tec",
        "mex",
        "pub",
        "rym",
        "tuc",
        "fyl",
        "lep",
        "deb",
        "ber",
        "mug",
        "hut",
        "tun",
        "byl",
        "sud",
        "pem",
        "dev",
        "lur",
        "def",
        "bus",
        "bep",
        "run",
        "mel",
        "pex",
        "dyt",
        "byt",
        "typ",
        "lev",
        "myl",
        "wed",
        "duc",
        "fur",
        "fex",
        "nul",
        "luc",
        "len",
        "ner",
        "lex",
        "rup",
        "ned",
        "lec",
        "ryd",
        "lyd",
        "fen",
        "wel",
        "nyd",
        "hus",
        "rel",
        "rud",
        "nes",
        "hes",
        "fet",
        "des",
        "ret",
        "dun",
        "ler",
        "nyr",
        "seb",
        "hul",
        "ryl",
        "lud",
        "rem",
        "lys",
        "fyn",
        "wer",
        "ryc",
        "sug",
        "nys",
        "nyl",
        "lyn",
        "dyn",
        "dem",
        "lux",
        "fed",
        "sed",
        "bec",
        "mun",
        "lyr",
        "tes",
        "mud",
        "nyt",
        "byr",
        "sen",
        "weg",
        "fyr",
        "mur",
        "tel",
        "rep",
        "teg",
        "pec",
        "nel",
        "nev",
        "fes"
      ]
    }
  end
end
