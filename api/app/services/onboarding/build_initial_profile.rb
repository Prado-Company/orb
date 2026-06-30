module Onboarding
  class BuildInitialProfile
    DEFAULTS = {
      main_goal: "rotina_geral",
      peak_windows: [],
      low_energy_windows: [],
      triggers: [],
      preferred_tone: "acolhedor",
      sensitivity: "media",
      notification_intensity: "equilibrado",
      first_check_in_time: "08:00",
      last_check_in_time: "18:00",
      meal_times: [],
      protected_breaks: [],
      confidence: "baixa"
    }.freeze

    FIRST_TERM_BY_WINDOW = {
      "manha_cedo" => "Cotovia",
      "manha cedo" => "Cotovia",
      "fim_da_manha" => "Cotovia",
      "fim da manha" => "Cotovia",
      "tarde" => "Pulso",
      "noite" => "Coruja",
      "madrugada" => "Coruja"
    }.freeze

    SECOND_TERM_BY_GOAL = {
      "trabalho" => "Estrategica",
      "estudo" => "Focada",
      "casa_e_familia" => "Cuidadora",
      "casa_familia" => "Cuidadora",
      "casa e familia" => "Cuidadora",
      "autocuidado" => "Restauradora",
      "transicao_de_carreira" => "Em Movimento",
      "transicao_carreira" => "Em Movimento",
      "transicao de carreira" => "Em Movimento",
      "rotina_geral" => "Versatil",
      "rotina geral" => "Versatil"
    }.freeze
    GOAL_ALIASES = {
      "casa_familia" => "casa_e_familia",
      "transicao_carreira" => "transicao_de_carreira"
    }.freeze
    NEURODIVERGENCE_ALIASES = {
      "autismo" => "tea_autismo",
      "tea" => "tea_autismo",
      "outras_condicoes" => "outras_condicoes_neurodivergentes",
      "nao_sei" => "nao_sei_tenho_duvidas",
      "tenho_duvidas" => "nao_sei_tenho_duvidas"
    }.freeze

    UNKNOWN_WINDOWS = %w[ainda_nao_sei ainda nao sei desconhecida desconhecido].freeze
    VARIABLE_WINDOWS = %w[varia_muito varia muito].freeze

    Result = Data.define(:attributes, :payload, :confidence, :skipped_sensitive_fields)

    def initialize(user:, responses:, source:)
      @user = user
      @responses = responses.deep_symbolize_keys
      @source = source
    end

    def call
      attributes = profile_attributes
      Result.new(
        attributes: attributes,
        payload: serialize_initial_profile(attributes),
        confidence: attributes[:confidence],
        skipped_sensitive_fields: neurodivergence_identifications.empty?
      )
    end

    private

    attr_reader :user, :responses, :source

    def profile_attributes
      values = DEFAULTS.merge(
        main_goal: normalize_goal(responses[:objetivo_principal] || responses[:main_goal]),
        peak_windows: normalize_array(responses[:janelas_pico] || responses[:peak_windows]),
        low_energy_windows: normalize_array(responses[:janelas_baixa_energia] || responses[:low_energy_windows]),
        triggers: normalize_array(responses[:gatilhos] || responses[:triggers]),
        preferred_tone: normalize_scalar(responses[:tom_preferido] || responses[:preferred_tone] || DEFAULTS[:preferred_tone]),
        sensitivity: normalize_scalar(responses[:sensibilidade] || responses[:sensitivity] || DEFAULTS[:sensitivity]),
        notification_intensity: normalize_scalar(responses[:intensidade_notificacao] || responses[:notification_intensity] || DEFAULTS[:notification_intensity]),
        first_check_in_time: normalize_time(
          responses[:horario_primeiro_check_in] || responses[:first_check_in_time],
          DEFAULTS[:first_check_in_time]
        ),
        last_check_in_time: normalize_time(
          responses[:horario_ultimo_check_in] || responses[:last_check_in_time],
          DEFAULTS[:last_check_in_time]
        ),
        meal_times: normalize_array(responses[:horarios_refeicoes] || responses[:meal_times]),
        protected_breaks: normalize_array(responses[:pausas_protegidas] || responses[:protected_breaks]),
        neurodivergent_identifications: neurodivergence_identifications
      )
      values[:confidence] = initial_confidence(values[:peak_windows])
      values[:archetype] = deterministic_archetype(values[:peak_windows], values[:main_goal])
      values[:source] = source
      values
    end

    def serialize_initial_profile(attributes)
      {
        version: 1,
        nome: responses[:nome].presence || user.name,
        pronomes: responses[:pronomes].presence || user.pronouns,
        timezone: responses[:timezone].presence || user.timezone,
        idioma: responses[:idioma].presence || user.locale,
        objetivo_principal: attributes[:main_goal],
        janelas_pico: attributes[:peak_windows],
        janelas_baixa_energia: attributes[:low_energy_windows],
        gatilhos: attributes[:triggers],
        sensibilidade: attributes[:sensitivity],
        tom_preferido: attributes[:preferred_tone],
        intensidade_notificacao: attributes[:notification_intensity],
        horario_primeiro_check_in: attributes[:first_check_in_time],
        horario_ultimo_check_in: attributes[:last_check_in_time],
        horarios_refeicoes: attributes[:meal_times],
        pausas_protegidas: attributes[:protected_breaks],
        arquetipo: attributes[:archetype],
        confianca_inicial: attributes[:confidence],
        data_onboarding: Time.current.utc.iso8601
      }
    end

    def deterministic_archetype(peak_windows, main_goal)
      first_term = first_term_for(peak_windows)
      second_term = SECOND_TERM_BY_GOAL.fetch(main_goal, "Versatil")
      second_term = "Restaurador" if first_term == "Explorador" && second_term == "Restauradora"

      "#{first_term} #{second_term}"
    end

    def first_term_for(peak_windows)
      normalized = peak_windows.map { |window| normalize_scalar(window) }
      return "Explorador" if normalized.empty? || normalized.any? { |window| UNKNOWN_WINDOWS.include?(window) }
      return "Pendulo" if normalized.length > 1 || normalized.any? { |window| VARIABLE_WINDOWS.include?(window) }

      FIRST_TERM_BY_WINDOW.fetch(normalized.first, "Explorador")
    end

    def initial_confidence(peak_windows)
      normalized = peak_windows.map { |window| normalize_scalar(window) }
      return "baixa" if normalized.empty?
      return "baixa" if normalized.any? { |window| UNKNOWN_WINDOWS.include?(window) || VARIABLE_WINDOWS.include?(window) }

      "media"
    end

    def normalize_goal(value)
      normalized = normalize_scalar(value.presence || DEFAULTS[:main_goal])
      GOAL_ALIASES.fetch(normalized, normalized)
    end

    def normalize_array(value)
      Array(value).map { |item| normalize_scalar(item) }.reject(&:blank?)
    end

    def normalize_scalar(value)
      value.to_s.strip.downcase.tr("-", "_").gsub(/\s+/, "_")
    end

    def normalize_time(value, fallback)
      raw = value.to_s.strip
      raw.match?(/\A\d{2}:\d{2}\z/) ? raw : fallback
    end

    def neurodivergence_identifications
      return [] unless NeurodivergenceUsePolicy.allowed?("personalizacao_acessivel")

      normalized = normalize_array(responses[:identificacoes_neurodivergentes]).map do |value|
        NEURODIVERGENCE_ALIASES.fetch(value, value)
      end
      normalized & EnergeticProfile::NEURODIVERGENT_IDENTIFICATIONS
    end
  end
end
