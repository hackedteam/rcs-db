module Bitcoin
  unless NETWORKS.keys.include?(:feathercoin)
    networks = NETWORKS

    __send__(:remove_const, :NETWORKS)

    networks[:feathercoin] = {
      project: :feathercoin,
      magic_head: "\xFB\xC0\xB6\xDB".force_encoding('BINARY'),
      address_version: "0e"
    }

    const_set(:NETWORKS, networks)
  end
end
