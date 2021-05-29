defmodule UrbitEx.Utils do
  @moduledoc """
  Utils module with some useful functions, such as a tokenizer for graph store, regex for urls and @ps, etc.
  """
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

  def calculate_index(unix_time) do
    da_unix_epoch = 170_141_184_475_152_167_957_503_069_145_530_368_000
    da_second = 18_446_744_073_709_551_616
    time_since_epoch = (unix_time * da_second / 1000) |> round
    da_unix_epoch + time_since_epoch
  end

  def tokenize(string) do
    urls = tokenize_item(string, :url)
    mentions = tokenize_item(string, :mention)
    non_text = [urls, mentions] |> List.flatten()
    text = extract_text(string)

    [text, non_text]
    |> List.flatten()
    |> Enum.sort_by(fn {_token, index} -> index end)
    |> Enum.map(fn {token, _ind} -> token end)
  end

  def tokenize_item(string, type) do
    list = extract_token(string, type)
    indexes = Regex.scan(regexes()[type], string, return: :index) |> List.flatten()

    list
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> {item, indexes |> Enum.at(index) |> elem(0)} end)
    |> Enum.map(fn {item, ind} -> {%{type => item}, ind} end)
  end

  def extract_text(string) do
    t =
      string
      |> String.split(regexes().url)
      |> Enum.map(&String.split(&1, regexes().mention))
      |> List.flatten()

    indexes =
      t
      |> Enum.map(fn x -> Regex.scan(Regex.compile!(x), string, return: :index) end)
      |> List.flatten()
      |> Enum.map(fn {ind, _length} -> ind end)

    t
    |> Enum.with_index()
    |> Enum.map(fn {item, ind} -> {item, Enum.at(indexes, ind)} end)
    |> Enum.map(fn {item, ind} -> {%{text: item}, ind} end)
  end

  def extract_token(string, type) do
    Regex.scan(regexes()[type], string) |> List.flatten()
  end

  def add_tilde(ship) do
    case Regex.match?(~r(^~), ship) do
      true -> ship
      false -> "~#{ship}"
    end
  end

  def remove_tilde(patp), do: patp |> String.replace(~r([~^]), "")

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

  def check_patp(shipname) do
    syllables = syllabize(shipname)

    if syllables do
      case length(syllables) do
        1 -> syllable_list().s |> Enum.member?(Enum.at(syllables, 0))
        2 -> check_bisyllable(syllables)
        4 -> check_long(syllables)
        6 -> check_long(syllables)
        8 -> check_long(syllables)
        16 -> check_long(syllables)
        _ -> false
      end
    else
      false
    end
  end

  def no_comets(shipname) do
    syllables = syllabize(shipname)

    cond do
      length(syllables) > 8 -> :gtfo
      true -> :ok
    end
  end

  def check_long(syllables) do
    join = syllables |> Enum.join()

    pairs =
      Regex.scan(~r(.{6}), join)
      |> List.flatten()
      |> Enum.map(fn x -> Regex.scan(~r/.{3}/, x) |> List.flatten() end)

    Enum.all?(pairs, fn x -> check_bisyllable(x) end)
  end

  def check_bisyllable(pair) do
    [pref, suf] = pair
    syllable_list().p |> Enum.member?(pref) && syllable_list().s |> Enum.member?(suf)
  end

  def syllabize(shipname) do
    clean = shipname |> String.replace(~r([~^-]), "")

    case rem(String.length(clean), 3) do
      0 -> Regex.scan(~r(.{3}), clean) |> List.flatten()
      _ -> false
    end
  end

  defp regexes do
    %{
      url: ~r/\w+:\/\/[-a-zA-Z0-9:@;?&=\/%\+\.\*!'\(\),\$_\{\}\^~\[\]`#|]+\w/,
      mention: ~r/~[bcdfghjlmnprstwz][aeiouy][\w^-]+/,
      code: ~r/`.+`/
    }
  end

  def syllable_list do
    %{
      p: [
        "bac",
        "bal",
        "ban",
        "bar",
        "bat",
        "bic",
        "bid",
        "bil",
        "bin",
        "bis",
        "bit",
        "bol",
        "bon",
        "bor",
        "bos",
        "bot",
        "dab",
        "dac",
        "dal",
        "dan",
        "dap",
        "dar",
        "das",
        "dat",
        "dav",
        "dib",
        "dif",
        "dig",
        "dil",
        "din",
        "dir",
        "dis",
        "div",
        "doc",
        "dol",
        "don",
        "dop",
        "dor",
        "dos",
        "dot",
        "dov",
        "doz",
        "fab",
        "fad",
        "fal",
        "fam",
        "fan",
        "fas",
        "fid",
        "fig",
        "fil",
        "fin",
        "fip",
        "fir",
        "fit",
        "fod",
        "fog",
        "fol",
        "fon",
        "fop",
        "for",
        "fos",
        "fot",
        "hab",
        "hac",
        "had",
        "hal",
        "han",
        "hap",
        "har",
        "has",
        "hat",
        "hav",
        "hid",
        "hil",
        "hin",
        "hob",
        "hoc",
        "hod",
        "hol",
        "hop",
        "hos",
        "lab",
        "lac",
        "lad",
        "lag",
        "lan",
        "lap",
        "lar",
        "las",
        "lat",
        "lav",
        "lib",
        "lid",
        "lig",
        "lin",
        "lis",
        "lit",
        "liv",
        "loc",
        "lod",
        "lom",
        "lon",
        "lop",
        "lor",
        "los",
        "mac",
        "mag",
        "mal",
        "map",
        "mar",
        "mas",
        "mat",
        "mic",
        "mid",
        "mig",
        "mil",
        "min",
        "mip",
        "mir",
        "mis",
        "mit",
        "moc",
        "mod",
        "mog",
        "mol",
        "mon",
        "mop",
        "mor",
        "mos",
        "mot",
        "nac",
        "nal",
        "nam",
        "nap",
        "nar",
        "nat",
        "nav",
        "nib",
        "nid",
        "nil",
        "nim",
        "nis",
        "noc",
        "nod",
        "nol",
        "nom",
        "nop",
        "nor",
        "nos",
        "nov",
        "pac",
        "pad",
        "pag",
        "pal",
        "pan",
        "par",
        "pas",
        "pat",
        "pic",
        "pid",
        "pil",
        "pin",
        "pit",
        "poc",
        "pod",
        "pol",
        "pon",
        "pos",
        "rab",
        "rac",
        "rad",
        "rag",
        "ral",
        "ram",
        "ran",
        "rap",
        "rav",
        "rib",
        "ric",
        "rid",
        "rig",
        "ril",
        "rin",
        "rip",
        "ris",
        "rit",
        "riv",
        "roc",
        "rol",
        "ron",
        "rop",
        "ros",
        "rov",
        "sab",
        "sal",
        "sam",
        "san",
        "sap",
        "sar",
        "sat",
        "sav",
        "sib",
        "sic",
        "sid",
        "sig",
        "sil",
        "sim",
        "sip",
        "sit",
        "siv",
        "soc",
        "sog",
        "sol",
        "som",
        "son",
        "sop",
        "sor",
        "sov",
        "tab",
        "tac",
        "tad",
        "tag",
        "tal",
        "tam",
        "tan",
        "tap",
        "tar",
        "tas",
        "tic",
        "tid",
        "til",
        "tim",
        "tin",
        "tip",
        "tir",
        "tob",
        "toc",
        "tod",
        "tog",
        "tol",
        "tom",
        "ton",
        "top",
        "tor",
        "wac",
        "wal",
        "wan",
        "wat",
        "wic",
        "wid",
        "win",
        "wis",
        "wit",
        "wol",
        "wor"
      ],
      s: [
        "bec",
        "bel",
        "ben",
        "bep",
        "ber",
        "bes",
        "bet",
        "bex",
        "bud",
        "bur",
        "bus",
        "byl",
        "byn",
        "byr",
        "byt",
        "deb",
        "dec",
        "def",
        "deg",
        "del",
        "dem",
        "den",
        "dep",
        "der",
        "des",
        "det",
        "dev",
        "dex",
        "duc",
        "dul",
        "dun",
        "dur",
        "dus",
        "dut",
        "dux",
        "dyl",
        "dyn",
        "dyr",
        "dys",
        "dyt",
        "feb",
        "fed",
        "fel",
        "fen",
        "fep",
        "fer",
        "fes",
        "fet",
        "fex",
        "ful",
        "fun",
        "fur",
        "fus",
        "fyl",
        "fyn",
        "fyr",
        "heb",
        "hec",
        "hep",
        "hes",
        "het",
        "hex",
        "hul",
        "hus",
        "hut",
        "leb",
        "lec",
        "led",
        "leg",
        "len",
        "lep",
        "ler",
        "let",
        "lev",
        "lex",
        "luc",
        "lud",
        "lug",
        "lun",
        "lup",
        "lur",
        "lus",
        "lut",
        "lux",
        "lyd",
        "lyn",
        "lyr",
        "lys",
        "lyt",
        "lyx",
        "meb",
        "mec",
        "med",
        "meg",
        "mel",
        "mep",
        "mer",
        "mes",
        "met",
        "mev",
        "mex",
        "mud",
        "mug",
        "mul",
        "mun",
        "mur",
        "mus",
        "mut",
        "myl",
        "myn",
        "myr",
        "neb",
        "nec",
        "ned",
        "nel",
        "nem",
        "nep",
        "ner",
        "nes",
        "net",
        "nev",
        "nex",
        "nub",
        "nul",
        "num",
        "nup",
        "nus",
        "nut",
        "nux",
        "nyd",
        "nyl",
        "nym",
        "nyr",
        "nys",
        "nyt",
        "nyx",
        "pec",
        "ped",
        "peg",
        "pel",
        "pem",
        "pen",
        "per",
        "pes",
        "pet",
        "pex",
        "pub",
        "pun",
        "pur",
        "put",
        "pyl",
        "pyx",
        "reb",
        "rec",
        "red",
        "ref",
        "reg",
        "rel",
        "rem",
        "ren",
        "rep",
        "res",
        "ret",
        "rev",
        "rex",
        "ruc",
        "rud",
        "rul",
        "rum",
        "run",
        "rup",
        "rus",
        "rut",
        "rux",
        "ryc",
        "ryd",
        "ryg",
        "ryl",
        "rym",
        "ryn",
        "ryp",
        "rys",
        "ryt",
        "ryx",
        "seb",
        "sec",
        "sed",
        "sef",
        "seg",
        "sel",
        "sem",
        "sen",
        "sep",
        "ser",
        "set",
        "sev",
        "sub",
        "sud",
        "sug",
        "sul",
        "sum",
        "sun",
        "sup",
        "sur",
        "sut",
        "syd",
        "syl",
        "sym",
        "syn",
        "syp",
        "syr",
        "syt",
        "syx",
        "teb",
        "tec",
        "ted",
        "teg",
        "tel",
        "tem",
        "ten",
        "tep",
        "ter",
        "tes",
        "tev",
        "tex",
        "tuc",
        "tud",
        "tug",
        "tul",
        "tun",
        "tus",
        "tux",
        "tyc",
        "tyd",
        "tyl",
        "tyn",
        "typ",
        "tyr",
        "tyv",
        "web",
        "wed",
        "weg",
        "wel",
        "wen",
        "wep",
        "wer",
        "wes",
        "wet",
        "wex",
        "wyc",
        "wyd",
        "wyl",
        "wyn",
        "wyt",
        "wyx",
        "zod"
      ]
    }
  end
end
