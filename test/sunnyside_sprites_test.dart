import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/sunnyside_sprites.dart';

void main() {
  group('SunnysideSprites crop mapping', () {
    test('canDraw returns true only for species with a Sunnyside crop', () {
      final sprites = SunnysideSprites();

      expect(sprites.canDraw(Species.carotte), isTrue);
      expect(sprites.canDraw(Species.tournesol), isTrue);
      expect(sprites.canDraw(Species.tomate), isTrue);
      expect(sprites.canDraw(Species.courgette), isTrue);
      expect(sprites.canDraw(Species.tulipe), isTrue);
      expect(sprites.canDraw(Species.lavande), isTrue);

      expect(sprites.canDraw(Species.pommier), isFalse);
      expect(sprites.canDraw(Species.poirier), isFalse);
    });

    test('stage index maps to harvest stage when ready', () {
      expect(
        SunnysideSprites.stageIndex(PlantStage.mature, true),
        equals(5),
      );
    });

    test('stage index maps mature without harvest to stage 4', () {
      expect(
        SunnysideSprites.stageIndex(PlantStage.mature, false),
        equals(4),
      );
    });

    test('stage index maps early stages', () {
      expect(
        SunnysideSprites.stageIndex(PlantStage.graineGermee, false),
        equals(0),
      );
      expect(
        SunnysideSprites.stageIndex(PlantStage.jeunePlant, false),
        equals(2),
      );
      expect(
        SunnysideSprites.stageIndex(PlantStage.presqueMature, false),
        equals(3),
      );
    });
  });
}
