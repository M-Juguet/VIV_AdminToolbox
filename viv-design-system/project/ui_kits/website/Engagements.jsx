function EngagementCard({ icon, title, body }) {
  return (
    <div className="viv-engagement">
      <div className="viv-engagement__icon">{icon}</div>
      <h3>{title}</h3>
      <p>{body}</p>
    </div>
  );
}

const IconSearch = (
  <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
);
const IconShield = (
  <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2 4 6v6c0 5 3.5 9 8 10 4.5-1 8-5 8-10V6l-8-4Z"/><path d="m9 12 2 2 4-4"/></svg>
);
const IconUsers = (
  <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
);
const IconBook = (
  <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z"/></svg>
);

function Engagements() {
  return (
    <section className="viv-section" id="engagements">
      <header className="viv-section__head">
        <span className="viv-eyebrow">Nos engagements</span>
        <h2 className="viv-h2">Plus qu'un simple partenaire.</h2>
        <p className="viv-section__lead">
          Véritable relais opérationnel sur la durée, de la sélection des talents jusqu'à la fin
          de leur mission, nous assurons un suivi quotidien rigoureux.
        </p>
      </header>
      <div className="viv-engagement-grid">
        <EngagementCard icon={IconSearch} title="Sourcing ciblé" body="Un vivier de talents qualifiés, sélectionnés selon vos besoins précis." />
        <EngagementCard icon={IconShield} title="Conformité juridique" body="Gestion tripartite claire : vous, le talent, VIV. Juridique et administratif pris en charge." />
        <EngagementCard icon={IconUsers}  title="Suivi des talents" body="Un interlocuteur unique, impliqué et disponible, tout au long de la mission." />
        <EngagementCard icon={IconBook}   title="Formation des talents" body="Montée en compétence continue, avec une place centrale pour l'IA." />
      </div>
    </section>
  );
}
window.Engagements = Engagements;
