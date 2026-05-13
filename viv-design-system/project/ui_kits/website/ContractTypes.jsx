function ContractTypes() {
  const types = ['CDD', 'CDI', 'Portage salarial', 'Freelance', 'Intermittent'];
  const [active, setActive] = React.useState('CDI');
  return (
    <section className="viv-contracts">
      <div className="viv-contracts__copy">
        <span className="viv-eyebrow">Des solutions pensées pour vous</span>
        <h2 className="viv-h2">Souples. <em>Sécurisées.</em> Centralisées.</h2>
        <p>
          Que vous ayez besoin d'un renfort ponctuel ou d'un accompagnement durable,
          notre équipe s'adapte à votre réalité. Contrats flexibles, conformité assurée.
        </p>
      </div>
      <div className="viv-contracts__chips">
        {types.map(t => (
          <button
            key={t}
            className={`viv-chip ${active === t ? 'is-active' : ''}`}
            onClick={() => setActive(t)}
          >
            {t}
          </button>
        ))}
      </div>
    </section>
  );
}
window.ContractTypes = ContractTypes;
