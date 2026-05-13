function TalentCard({ title, body, gradient, label }) {
  return (
    <article className="viv-talent">
      <div className="viv-talent__media" style={{ background: gradient }}>
        <span className="viv-talent__media-label">{label}</span>
      </div>
      <div className="viv-talent__body">
        <h3>{title}</h3>
        <p>{body}</p>
        <a className="viv-link" href="#">Découvrir nos talents →</a>
      </div>
    </article>
  );
}

function TalentCategories() {
  return (
    <section className="viv-section" id="talents">
      <header className="viv-section__head">
        <span className="viv-eyebrow">Nos talents</span>
        <h2 className="viv-h2">Trouvez le bon talent au bon moment !</h2>
        <p className="viv-section__lead">
          Ingénieurs, experts IT, consultants digitaux ou créatifs — des profils qualifiés,
          sélectionnés avec soin, capables d'intégrer vos équipes et de contribuer
          immédiatement à faire grandir vos projets.
        </p>
      </header>
      <div className="viv-talent-grid">
        <TalentCard
          title="Design"
          label="Design"
          gradient="linear-gradient(135deg, #1a1a1a 0%, #4a4a4a 100%)"
          body="Créatifs et exigeants, nos designers transforment les idées en expériences visuelles et produits sur mesure, alliant esthétique, innovation et performance."
        />
        <TalentCard
          title="Digital"
          label="Digital"
          gradient="linear-gradient(135deg, #2d2d2d 0%, #6a6a6a 100%)"
          body="Marketing, e-commerce, production et post-production de contenus, coordination de projets digitaux — pour renforcer votre visibilité et votre impact en ligne."
        />
        <TalentCard
          title="Systèmes d'information"
          label="SI"
          gradient="linear-gradient(135deg, #0f0f0f 0%, #3a3a3a 100%)"
          body="Développeurs, data engineers ou chefs de projet IT : nos talents renforcent vos équipes des systèmes d'information pour des projets performants et sécurisés."
        />
      </div>
    </section>
  );
}
window.TalentCategories = TalentCategories;
