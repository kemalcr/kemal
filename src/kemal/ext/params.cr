module HTTP
  struct Params
    def [](name)
      params = raw_params[name]
      params.size == 1 ? params.first : params
    end
  end
end
