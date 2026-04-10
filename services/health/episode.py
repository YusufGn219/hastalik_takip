from django.utils import timezone
from apps.health.models import Episode, EpisodeLocationEntry


def get_active_episode(user, symptom):
    return Episode.objects.filter(
        user=user,
        symptom=symptom,
        status=Episode.Status.ONGOING
    ).first()


def start_episode(user, symptom_entry):
    episode = Episode.objects.create(
        user=user,
        symptom=symptom_entry.symptom,
        start_time=symptom_entry.timestamp,
        status=Episode.Status.ONGOING
    )

    symptom_entry.episode = episode
    symptom_entry.save()

    if symptom_entry.location:
        EpisodeLocationEntry.objects.create(
            episode=episode,
            location=symptom_entry.location,
            added_at=symptom_entry.timestamp
        )

    return episode


def add_to_episode(episode, symptom_entry, is_new_location=False):
    symptom_entry.episode = episode
    symptom_entry.save()

    if is_new_location and symptom_entry.location:
        existing_locations = episode.location_entries.values_list('location', flat=True)
        if symptom_entry.location not in existing_locations:
            EpisodeLocationEntry.objects.create(
                episode=episode,
                location=symptom_entry.location,
                added_at=symptom_entry.timestamp
            )

    return episode


def close_episode(episode, ended_at=None, resolution_notes=''):
    if episode.status == Episode.Status.RESOLVED:
        raise ValueError('Bu episode zaten kapatılmış.')

    episode.ended_at = ended_at or timezone.now()
    episode.status = Episode.Status.RESOLVED
    episode.resolution_notes = resolution_notes
    episode.save()

    return episode


def get_duration_minutes(episode):
    if not episode.ended_at:
        return None
    delta = episode.ended_at - episode.start_time
    return int(delta.total_seconds() / 60)

def close_episode(episode, ended_at=None, resolution_notes=''):
    if episode.status == Episode.Status.RESOLVED:
        raise ValueError('Bu episode zaten kapatılmış.')

    final_end_time = ended_at or timezone.now()

    if final_end_time <= episode.start_time:  # YENİ
        raise ValueError('Bitiş zamanı başlangıç zamanından önce olamaz.')

    episode.ended_at = final_end_time
    episode.status = Episode.Status.RESOLVED
    episode.resolution_notes = resolution_notes
    episode.save()

    return episode